//
//  AdWindowPresenter.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/16.
//

import UIKit
import GoogleMobileAds // MobileAds をインポート

// 広告表示のための一時的なUIWindowを管理するヘルパークラス
class AdWindowPresenter: NSObject {
    private var adWindow: UIWindow?
    private var adCompletionHandler: (() -> Void)? // 広告が閉じた時に呼ぶためのハンドラ

    // 広告を表示する
    func presentAd(ad: InterstitialAd, completion: @escaping () -> Void) {
        self.adCompletionHandler = completion // 広告が閉じられた時に呼ぶハンドラを保持

        // 新しいUIWindowを作成し、最上位に配置
        adWindow = UIWindow(frame: UIScreen.main.bounds)
        adWindow?.rootViewController = UIViewController() // 空のUIViewControllerをルートにする
        adWindow?.windowLevel = .alert + 1 // 通常の警告ビューより上に表示
        adWindow?.makeKeyAndVisible()

        // 広告を表示
        if let rootVC = adWindow?.rootViewController {
            ad.present(from: rootVC)
            // 広告が正常に提示されたら、広告が閉じたときに dismissAdWindow を呼ぶように設定される
        } else {
            // ルートVCが取得できない場合は、即座に完了ハンドラを呼んでウィンドウを閉じる
            print("❗️ AdWindowPresenter: rootViewController が取得できませんでした。")
            dismissAdWindow()
        }
    }

    // 広告ウィンドウを閉じる
    func dismissAdWindow() {
        adWindow?.isHidden = true
        adWindow = nil // ウィンドウを破棄
        adCompletionHandler?() // 広告が閉じられた際の完了ハンドラを呼び出す
        adCompletionHandler = nil
    }
}
