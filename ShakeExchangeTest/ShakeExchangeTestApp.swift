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
import UserNotifications
import FirebaseMessaging
import FirebaseFirestore

// MARK: - AppDelegate: Firebaseの初期化を担当
// UIResponderとUIApplicationDelegateに準拠
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate{
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
        
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            } else {
                print("⚠️ Notification permission denied")
            }
        }
        
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()
        return true
        
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        print("✅ APNs token registered.")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("❌ Error fetching FCM token: \(error)")
            } else if let token = token, let uid = Auth.auth().currentUser?.uid {
                print("📡 FCM token: \(token)")
                let db = Firestore.firestore()
                db.collection("users").document(uid).setData(["fcmToken": token], merge: true)
            }
        }
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📲 FCM Token (delegate): \(fcmToken ?? "nil")")
        if let token = fcmToken, let uid = Auth.auth().currentUser?.uid {
            Firestore.firestore().collection("users").document(uid).setData(["fcmToken": token], merge: true)
        }
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
