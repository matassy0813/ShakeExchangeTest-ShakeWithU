//
//  AuthManager.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/05.
//
import Foundation
import FirebaseAuth // FirebaseAuthをインポート
import FirebaseFirestore // Firestoreをインポート (必要に応じて)

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated: Bool = false // ユーザーが認証されているか
    @Published var userId: String? // 認証されたユーザーのID
    @Published var errorMessage: String? // エラーメッセージ
    @Published var needsInitialProfileSetup: Bool = false // 初期プロフィール設定が必要か
    @Published var hasAgreedToTerms: Bool = false // 利用規約とプライバシーポリシーに同意済みか

    private var authHandle: AuthStateDidChangeListenerHandle? // 認証状態リスナーのハンドル
    private let userDefaultsTermsKey = "hasAgreedToTerms" // UserDefaultsのキー

    private init() {
        // Firebase Authのインスタンスを取得
        let auth = Auth.auth()

        // 認証状態の変更を監視
        authHandle = auth.addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            // メインスレッドでPublishedプロパティを更新
            DispatchQueue.main.async {
                if let user = user {
                    // ユーザーが認証されている場合
                    self.isAuthenticated = true
                    self.userId = user.uid
                    self.errorMessage = nil
                    print("[AuthManager] ✅ ユーザー認証済み: \(user.uid)")
                    
                    // needsInitialProfileSetup の設定はProfileManagerに完全に任せる
                    // ProfileManagerがプロフィールをロードし、その結果に基づいてneedsInitialProfileSetupを更新する
                    
                    // 利用規約への同意状態をロード
                    self.loadTermsAgreementStatus()
                } else {
                    // ユーザーが認証されていない場合
                    self.isAuthenticated = false
                    self.userId = nil
                    self.hasAgreedToTerms = false // 未認証の場合は同意状態をリセット
                    print("[AuthManager] ℹ️ ユーザー未認証。")
                    // 未認証になったらProfileManagerをリセット
//                    ProfileManager.shared.resetProfileForUnauthenticatedUser()
                }
            }
        }
    }

    // デイニシャライザでリスナーを削除
    deinit {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
            print("[AuthManager] 🛑 認証状態リスナーを削除しました。")
        }
    }

    // MARK: - 新規ユーザー登録 (サインアップ)
    func signUp(email: String, password: String) async -> Bool {
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            print("[AuthManager] ✅ サインアップ成功: \(result.user.uid)")
            // サインアップ成功時にlastLoginDateを更新
            await ProfileManager.shared.updateLastLoginDate()
            return true
        } catch {
            errorMessage = error.localizedDescription
            print("[AuthManager] ❌ サインアップ失敗: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 既存ユーザーログイン (サインイン)
    func signIn(email: String, password: String) async -> Bool {
        errorMessage = nil
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("[AuthManager] ✅ サインイン成功: \(result.user.uid)")
            // サインイン成功時にlastLoginDateを更新
            await ProfileManager.shared.updateLastLoginDate()
            return true
        } catch {
            errorMessage = error.localizedDescription
            print("[AuthManager] ❌ サインイン失敗: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - ログアウト
    func signOut() async -> Bool {
        errorMessage = nil
        do {
            try Auth.auth().signOut()
            print("[AuthManager] ✅ サインアウト成功。")
//            self.needsInitialProfileSetup = false
//            self.hasAgreedToTerms = false // ログアウト時に同意状態をリセット
            saveTermsAgreementStatus() // UserDefaultsも更新
            // ローカルのプロフィールデータもリセット
            // この処理はProfileManager.shared.resetProfileForUnauthenticatedUser() に任せる
            return true
        } catch {
            errorMessage = error.localizedDescription
            print("[AuthManager] ❌ サインアウト失敗: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - セッション有効期限チェック (アプリ起動時に呼び出す)
    // このメソッドは、ProfileManagerがcurrentUser.lastLoginDateをFirestoreから
    // 完全にロードした後に呼び出すべきです。
    func checkSessionValidity() async {
        guard isAuthenticated, let userId = self.userId else {
            print("[AuthManager] ℹ️ セッションチェック: ユーザーは認証されていません。")
            return
        }
        
        // ProfileManagerから最新のlastLoginDateを取得
        // ここで再度ロードするのは、ProfileManagerの監視がまだ完了していない場合の安全策
        // ただし、理想的にはProfileManagerのロード完了を待つべき
        await ProfileManager.shared.loadProfileFromFirestore(userId: userId)
        guard let lastLoginDate = await ProfileManager.shared.currentUser.lastLoginDate else {
            print("[AuthManager] ℹ️ セッションチェック: lastLoginDate が見つかりません。再認証を促します。")
            await signOut() // lastLoginDate がない場合はログアウト
            return
        }
        
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        
        if lastLoginDate < sevenDaysAgo {
            print("[AuthManager] ⚠️ セッション有効期限切れ: 1週間以上ログインしていません。再認証を促します。")
            await signOut() // 強制ログアウト
        } else {
            print("[AuthManager] ✅ セッション有効: 最終ログインから1週間以内です。")
        }
    }

    // MARK: - 利用規約同意状態の保存
    func saveTermsAgreementStatus() {
        UserDefaults.standard.set(hasAgreedToTerms, forKey: userDefaultsTermsKey)
        print("[AuthManager] ✅ 利用規約同意状態をUserDefaultsに保存しました: \(hasAgreedToTerms)")
    }

    // MARK: - 利用規約同意状態のロード
    private func loadTermsAgreementStatus() {
        // 認証済みの場合のみロードし、未認証の場合は常にfalse
        if isAuthenticated {
            hasAgreedToTerms = UserDefaults.standard.bool(forKey: userDefaultsTermsKey)
            print("[AuthManager] ✅ 利用規約同意状態をUserDefaultsからロードしました: \(hasAgreedToTerms)")
        } else {
            hasAgreedToTerms = false
        }
    }
}

