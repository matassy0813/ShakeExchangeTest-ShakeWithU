//
//  ShakeExchangeTestApp.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/19.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseAppCheck // FirebaseAppCheck をインポートします
import GoogleMobileAds // ← ファイル先頭に追加

// MARK: - AppDelegate: Firebaseの初期化を担当
// UIResponderとUIApplicationDelegateに準拠
class AppDelegate: NSObject, UIApplicationDelegate {
    // アプリケーション起動時の処理
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["5fe5335979b06b695af69c7ae6f1e424"]
        MobileAds.shared.start()
        // MARK: - Firebase App Check の設定
        // FirebaseApp.configure() の前に設定が必要です
        let appCheckFactory = MyAppCheckProviderFactory() // カスタムファクトリのインスタンスを作成
        AppCheck.setAppCheckProviderFactory(appCheckFactory) // shared なしで呼び出す形を試す

        // Firebaseを初期化 (App Check の設定後に行う)
        FirebaseApp.configure()
        print("[AppDelegate] ✅ Firebase configured successfully.")
        return true
    }
    
    // 他のAppDelegateのライフサイクルメソッドが必要な場合、ここに追加できます
}

// MARK: - カスタム AppCheckProviderFactory
// このクラスはAppDelegateの外側（同じファイル内、または別のファイル）に記述します
class MyAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        // DEBUG ビルドでは AppCheckDebugProvider を使用
        return AppCheckDebugProvider(app: app)
        #else
        // RELEASE ビルド (本番環境) では DeviceCheckProvider を使用
        return DeviceCheckProvider(app: app)
        #endif
    }
}


// MARK: - ShakeExchangeTestApp: SwiftUIアプリケーションのエントリポイント
@main
struct ShakeExchangeTestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject var authManager = AuthManager.shared
    @StateObject var profileManager = ProfileManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    if authManager.needsInitialProfileSetup {
                        InitialProfileSetupView()
                            .onAppear {
                                print("[ShakeExchangeTestApp] ➡️ 認証済み、初期プロフィール設定画面へ遷移。")
                            }
                    } else {
                        ContentView()
                            .background(Color.black)
                            .ignoresSafeArea()
                            .environmentObject(FriendManager.shared)
                            .onAppear {
                                print("[ShakeExchangeTestApp] ➡️ 認証済み、メインコンテンツへ遷移。")
                            }
                    }
                } else {
                    AuthView()
                        .onAppear {
                            print("[ShakeExchangeTestApp] ➡️ 未認証のためログインページを表示。")
                        }
                }
            }
            .onAppear {
                Task {
                    await authManager.checkSessionValidity()
                }
            }
        }
    }
}
