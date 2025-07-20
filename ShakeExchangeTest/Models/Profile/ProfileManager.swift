//
//  ProfileManager.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//
import SwiftUI
import Foundation
import FirebaseFirestore // Firestoreをインポート
import FirebaseAuth // FirebaseAuthをインポート
import Combine // Combineフレームワークをインポート

final class ProfileManager: ObservableObject {
    static let shared = ProfileManager()
    
    @Published var currentUser: CurrentUser = CurrentUser(
        uuid: "",
        name: "Setup Profile", // 初期設定を促すための仮の名前
        description: "",
        icon: "profile_startImage",
        link: "",
        challengeStatus: 0,
        recentPhotos: [],
        lastLoginDate: nil
    ) {
        didSet {
            // currentUserが変更されたらFirestoreに保存を試みる
            // ただし、AuthManagerが認証済みでuserIdが設定されている場合のみ
            if AuthManager.shared.isAuthenticated, let _ = AuthManager.shared.userId {
                Task {
                    await saveProfileToFirestore()
                }
            }
        }
    }

    @Published var isProfileLoaded: Bool = false // プロフィールがFirestoreから読み込まれたかどうかのフラグ
    
    private var db: Firestore!
    private var auth: Auth!
    private let userDefaultsKey = "CurrentUserProfile" // ローカル保存用キー (初回起動時やオフライン対応のため残す)
    private var cancellables = Set<AnyCancellable>() // Combineフレームワークのcancellablesセット

    init() {
        db = Firestore.firestore()
        auth = Auth.auth()
        
        // まずUserDefaultsから読み込みを試みる (アプリ起動時の初期表示を高速化するため)
        loadProfileFromUserDefaults()
        print("[ProfileManager] ℹ️ ProfileManager初期化完了。UserDefaultsからプロフィールをロードしました。")

        // AuthManagerの認証状態変更を監視し、プロフィールのロードをトリガーする
        // ここではisProfileLoadedの状態を更新するのみで、リセットはresetProfileForUnauthenticatedUser() に任せる
        AuthManager.shared.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    // AuthManagerの認証状態が変更されたらisProfileLoadedを更新
                    self.isProfileLoaded = isAuthenticated
                    print("[ProfileManager] ℹ️ AuthManagerの認証状態が変更されました。isProfileLoaded: \(self.isProfileLoaded)")
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 未認証ユーザー向けプロフィールリセット
    // AuthManagerから呼び出されることを想定
    func resetProfileForUnauthenticatedUser() {
        DispatchQueue.main.async {
            self.currentUser = CurrentUser(
                uuid: "",
                name: "Setup Profile",
                description: "",
                icon: "profile_startImage",
                link: "",
                challengeStatus: 0,
                recentPhotos: [],
                lastLoginDate: nil
            )
            self.isProfileLoaded = false // 未認証なのでプロフィールはロードされていない状態
            AuthManager.shared.needsInitialProfileSetup = true // 初期設定が必要な状態にする
            self.saveProfileToUserDefaults() // ローカルもクリア
            print("[ProfileManager] ℹ️ 未認証のためローカルプロフィールをリセットし、初期設定が必要に設定しました。")
        }
    }

    // MARK: - プロフィール保存 (UserDefaults)
    func saveProfileToUserDefaults() {
        do {
            let data = try JSONEncoder().encode(currentUser)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            print("[ProfileManager] ✅ プロフィールUserDefaults保存完了")
        } catch {
            print("[ProfileManager] ❌ UserDefaults保存失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - プロフィール読み込み (UserDefaults)
    private func loadProfileFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let user = try JSONDecoder().decode(CurrentUser.self, from: data)
                currentUser = user
                print("[ProfileManager] ✅ プロフィールUserDefaults読み込み成功: \(user.uuid)")
            } catch {
                print("[ProfileManager] ❌ UserDefaults読み込み失敗: \(error.localizedDescription)")
            }
        } else {
            print("[ProfileManager] ℹ️ UserDefaultsにプロフィールが見つかりません。")
        }
    }

    // MARK: - プロフィール保存 (Firestore)
    func saveProfileToFirestore() async {
        guard let userId = AuthManager.shared.userId else { // AuthManagerからuserIdを取得
            print("[ProfileManager] ⚠️ User IDが未設定のためFirestoreに保存できません。")
            return
        }
        
        // Firestoreのパス: /users/{userId}/profile/current
        let profileRef = db.collection("users").document(userId).collection("profile").document("current")
        
        // currentUserのUUIDをFirebaseのuserIdと同期させる
        DispatchQueue.main.async {
            if self.currentUser.uuid != userId {
                self.currentUser.uuid = userId
                print("[ProfileManager] ⚙️ currentUser.uuidをFirebase User IDに同期: \(userId)")
            }
        }

        do {
            let data = try Firestore.Encoder().encode(currentUser)
            try await profileRef.setData(data)
            print("[ProfileManager] ✅ Firestoreにプロフィール保存完了: \(currentUser.uuid)")
            saveProfileToUserDefaults() // Firestore保存成功後、UserDefaultsも更新
            
            // プロフィールが正常に保存されたので、初期設定は不要
            DispatchQueue.main.async {
                AuthManager.shared.needsInitialProfileSetup = false
                print("[ProfileManager] ℹ️ needsInitialProfileSetupをfalseに設定 (Firestore保存成功)")
            }
        } catch {
            print("[ProfileManager] ❌ Firestore保存失敗: \(error.localizedDescription)")
            print("[ProfileManager] ⚠️ Firestore保存失敗。needsInitialProfileSetup: \(AuthManager.shared.needsInitialProfileSetup) (エラー: \(error.localizedDescription))")
        }
    }

    // MARK: - プロフィール読み込み (Firestore)
    func loadProfileFromFirestore(userId: String) async { // userIdを引数で受け取る
        print("[ProfileManager] 🔄 Firestoreからプロフィールをロード中... User ID: \(userId)")
        let profileRef = db.collection("users").document(userId).collection("profile").document("current")
        
        do {
            let document = try await profileRef.getDocument()
            if document.exists {
                let user = try document.data(as: CurrentUser.self)
                DispatchQueue.main.async {
                    self.currentUser = user
                    self.isProfileLoaded = true // プロフィールが正常にロードされた
                    print("[ProfileManager] ✅ Firestoreからプロフィール読み込み成功: \(user.uuid)。isProfileLoaded: \(self.isProfileLoaded)")
                    self.saveProfileToUserDefaults() // Firestoreから読み込み成功後、UserDefaultsも更新
                    
                    // プロフィールが存在するので、初期設定は不要と判断
                    AuthManager.shared.needsInitialProfileSetup = false // <-- ここでfalseに設定
                    print("[ProfileManager] ℹ️ needsInitialProfileSetupをfalseに設定 (プロフィール存在)")
                }
            } else {
                print("[ProfileManager] ℹ️ Firestoreにプロフィールが見つかりません。初期プロフィール設定が必要です。")
                // Firestoreにデータがない場合、初期プロフィール設定が必要な状態にする
                DispatchQueue.main.async {
                    self.currentUser = CurrentUser(
                        uuid: userId, // 新規ユーザーなのでUUIDをFirebase User IDに設定
                        name: "Setup Profile", // UIで初期設定を促すための仮の名前
                        description: "",
                        icon: "profile_startImage",
                        link: "",
                        challengeStatus: 0,
                        recentPhotos: [],
                        lastLoginDate: nil
                    )
                    self.isProfileLoaded = true // データは初期化されたが、ロード処理は完了したと見なす
                    AuthManager.shared.needsInitialProfileSetup = true // AuthManagerのフラグを更新
                    self.saveProfileToUserDefaults() // ローカルも更新
                    print("[ProfileManager] ℹ️ needsInitialProfileSetupをtrueに設定 (プロフィールなし)。isProfileLoaded: \(self.isProfileLoaded)")
                }
            }
        } catch {
            print("[ProfileManager] ❌ Firestore読み込み失敗: \(error.localizedDescription)")
            // 読み込み失敗時はUserDefaultsのデータを使用し、UUIDがなければ生成
            DispatchQueue.main.async {
                if self.currentUser.uuid.isEmpty { // UserDefaultsから読み込めていない場合
                    self.currentUser.uuid = userId // Firebase User IDを使用
                    print("[ProfileManager] ⚙️ UUID自動生成 (Firestore読み込み失敗時): \(self.currentUser.uuid)")
                }
                self.isProfileLoaded = true // エラーでロードは完了したと見なす
                // エラー時も needsInitialProfileSetup を適切に設定
                AuthManager.shared.needsInitialProfileSetup = self.currentUser.name == "Setup Profile" || self.currentUser.name.isEmpty
                print("[ProfileManager] ℹ️ needsInitialProfileSetupを\(AuthManager.shared.needsInitialProfileSetup)に設定 (Firestore読み込みエラー)。isProfileLoaded: \(self.isProfileLoaded)")
                Task {
                    await self.saveProfileToFirestore() // エラー時もFirestoreへの保存を試みる
                }
            }
        }
    }
}

