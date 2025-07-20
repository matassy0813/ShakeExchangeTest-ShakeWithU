//
//  ShakeHostingController.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/23.
//
import SwiftUI

class ShakeHostingController: UIHostingController<ShakeButtonView> {
    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
        print("[ShakeHostingController] becomeFirstResponder 呼び出し")
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            print("[ShakeHostingController] シェイク検知されました")
            MultipeerManager.shared.detectHandshake()
        }
    }
}



