//
//  SceneDelegate.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/23.
//
import UIKit
import SwiftUI
import Combine

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            let rootView = ShakeButtonView()
            window.rootViewController = ShakeHostingController(rootView: rootView)
            self.window = window
            window.makeKeyAndVisible()
        }
    }
}
