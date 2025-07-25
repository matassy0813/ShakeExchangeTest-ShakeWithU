//
//  ProfileManager.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//
import SwiftUI
import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class ProfileManager: ObservableObject {
    static let shared = ProfileManager()
    
    @Published var currentUser: CurrentUser = CurrentUser(
        uuid: "",
        name: "Setup Profile",
        description: "",
        icon: "profile_startImage",
        link: "",
        challengeStatus: 0,
        recentPhotos: [],
        lastLoginDate: nil
    ) {
        didSet {
            // currentUserが空でない場合だけFirestoreへ保存
            if AuthManager.shared.isAuthenticated,
               let _ = AuthManager.shared.userId,
               !currentUser.uuid.isEmpty,
               currentUser.name != "Setup Profile" // ← 本当に有効なプロフィールの時だけ保存
            {
                Task {
                    await saveProfileToFirestore()
                }
            } else {
                print("[ProfileManager] ℹ️ didSetでのFirestore保存をスキップ（未認証または初期状態）")
            }
        }
    }

    @Published var isProfileLoaded: Bool = false
    
    private var db: Firestore!
    private var auth: Auth!
    private let userDefaultsKey = "CurrentUserProfile"
    private var cancellables = Set<AnyCancellable>()

    init() {
        db = Firestore.firestore()
        auth = Auth.auth()

        loadProfileFromUserDefaults()
        print("[ProfileManager] ℹ️ ProfileManager初期化完了。UserDefaultsからプロフィールをロードしました。")

        // 🔧 修正：明示的に currentUser が存在するかチェックしてからロジックを進める
        if let user = Auth.auth().currentUser {
            let uid = user.uid
            print("[ProfileManager] ✅ 起動時に currentUser 存在確認: \(uid)")
            Task {
                await self.loadProfileFromFirestore(userId: uid)
            }
        } else {
            print("[ProfileManager] ℹ️ 起動時に currentUser が nil のため、まだ未認証と判断。")
        }

        AuthManager.shared.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isProfileLoaded = isAuthenticated
                    print("[ProfileManager] ℹ️ AuthManagerの認証状態が変更されました。isProfileLoaded: \(self.isProfileLoaded)")
                }
                if isAuthenticated, let userId = AuthManager.shared.userId {
                    Task {
                        await self.loadProfileFromFirestore(userId: userId)
                    }
                } else {
//                    self.resetProfileForUnauthenticatedUser()
                }
            }
            .store(in: &cancellables)
    }


    // MARK: - 未認証ユーザー向けプロフィールリセット
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
            self.isProfileLoaded = false
            AuthManager.shared.needsInitialProfileSetup = true
            self.saveProfileToUserDefaults()
            print("[ProfileManager] ℹ️ 未認証のためローカルプロフィールをリセットし、初期設定が必要に設定しました。")
        }
    }

    // MARK: - プロフィール保存 (UserDefaults)
    func saveProfileToUserDefaults() { //
        do {
            let data = try JSONEncoder().encode(currentUser)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            print("[ProfileManager] ✅ プロフィールUserDefaults保存完了")
        } catch {
            print("[ProfileManager] ❌ UserDefaults保存失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - プロフィール読み込み (UserDefaults)
    private func loadProfileFromUserDefaults() { //
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
    func saveProfileToFirestore() async { //
        guard let userId = AuthManager.shared.userId else {
            print("[ProfileManager] ⚠️ User IDが未設定のためFirestoreに保存できません。")
            return
        }
        
        let profileRef = db.collection("users").document(userId).collection("profile").document("current")
        
        DispatchQueue.main.async {
            if self.currentUser.uuid != userId {
                self.currentUser.uuid = userId
                print("[ProfileManager] ⚙️ currentUser.uuidをFirebase User IDに同期: \(userId)")
            }
        }

        do {
            var data = try Firestore.Encoder().encode(currentUser)
            // lastLoginDate が nil の場合、またはサインイン/サインアップ直後の場合は現在時刻を設定
            if currentUser.lastLoginDate == nil || data["lastLoginDate"] == nil { //
                data["lastLoginDate"] = Timestamp(date: Date()) //
                DispatchQueue.main.async { //
                    self.currentUser.lastLoginDate = Date() //
                }
            }
            
            try await profileRef.setData(data)
            print("[ProfileManager] ✅ Firestoreにプロフィール保存完了: \(currentUser.uuid)")
            saveProfileToUserDefaults() //
            
            DispatchQueue.main.async { //
                AuthManager.shared.needsInitialProfileSetup = false //
                print("[ProfileManager] ℹ️ needsInitialProfileSetupをfalseに設定 (Firestore保存成功)") //
            }
        } catch {
            print("[ProfileManager] ❌ Firestore保存失敗: \(error.localizedDescription)")
            print("[ProfileManager] ⚠️ Firestore保存失敗。needsInitialProfileSetup: \(AuthManager.shared.needsInitialProfileSetup) (エラー: \(error.localizedDescription))")
        }
    }

    // MARK: - プロフィール読み込み (Firestore)
    func loadProfileFromFirestore(userId: String) async { //
        print("[ProfileManager] 🔄 Firestoreからプロフィールをロード中... User ID: \(userId)")
        let profileRef = db.collection("users").document(userId).collection("profile").document("current")
        
        do {
            let document = try await profileRef.getDocument()
            if document.exists {
                let user = try document.data(as: CurrentUser.self)
                DispatchQueue.main.async {
                    self.currentUser = user
                    self.isProfileLoaded = true
                    print("[ProfileManager] ✅ Firestoreからプロフィール読み込み成功: \(user.uuid)。isProfileLoaded: \(self.isProfileLoaded)")
                    self.saveProfileToUserDefaults()
                    
                    AuthManager.shared.needsInitialProfileSetup = false
                    print("[ProfileManager] ℹ️ needsInitialProfileSetupをfalseに設定 (プロフィール存在)")
                }
            } else {
                print("[ProfileManager] ℹ️ Firestoreにプロフィールが見つかりません。初期プロフィール設定が必要です。")
                DispatchQueue.main.async {
                    self.currentUser = CurrentUser(
                        uuid: userId,
                        name: "Setup Profile",
                        description: "",
                        icon: "profile_startImage",
                        link: "",
                        challengeStatus: 0,
                        recentPhotos: [],
                        lastLoginDate: nil
                    )
                    self.isProfileLoaded = true
                    AuthManager.shared.needsInitialProfileSetup = true
                    self.saveProfileToUserDefaults()
                    print("[ProfileManager] ℹ️ needsInitialProfileSetupをtrueに設定 (プロフィールなし)。isProfileLoaded: \(self.isProfileLoaded)")
                }
            }
        } catch {
            print("[ProfileManager] ❌ Firestore読み込み失敗: \(error.localizedDescription)")
            DispatchQueue.main.async {
                if self.currentUser.uuid.isEmpty {
                    self.currentUser.uuid = userId
                    print("[ProfileManager] ⚙️ UUID自動生成 (Firestore読み込み失敗時): \(self.currentUser.uuid)")
                }
                self.isProfileLoaded = true
                AuthManager.shared.needsInitialProfileSetup = self.currentUser.name == "Setup Profile" || self.currentUser.name.isEmpty
                print("[ProfileManager] ℹ️ needsInitialProfileSetupを\(AuthManager.shared.needsInitialProfileSetup)に設定 (Firestore読み込みエラー)。isProfileLoaded: \(self.isProfileLoaded)")
                Task {
                    await self.saveProfileToFirestore()
                }
            }
        }
    }
    
    // MARK: - lastLoginDate の更新
    func updateLastLoginDate() async { //
        guard let userId = AuthManager.shared.userId else {
            print("[ProfileManager] ⚠️ User IDが未設定のためlastLoginDateを更新できません。")
            return
        }
        let profileRef = db.collection("users").document(userId).collection("profile").document("current")
        do {
            try await profileRef.updateData(["lastLoginDate": Timestamp(date: Date())])
            DispatchQueue.main.async {
                self.currentUser.lastLoginDate = Date()
                print("[ProfileManager] ✅ FirestoreのlastLoginDateを更新しました。")
            }
        } catch {
            print("[ProfileManager] ❌ lastLoginDateの更新に失敗しました: \(error.localizedDescription)")
        }
    }
}
