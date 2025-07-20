//
//  InterstitialAdManager.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/16.
//

import GoogleMobileAds
import SwiftUI

class InterstitialAdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    private var interstitial: InterstitialAd?
    // AdWindowPresenter は使用しないため削除
    // private var adWindowPresenter: AdWindowPresenter?

    // 広告が閉じられた後に実行するクロージャ
    private var onAdDismissedCompletion: (() -> Void)?
    // 広告が表示された後に実行するクロージャ（adDidRecordImpression に移行）
    private var onAdImpressionRecordedCompletion: (() -> Void)? // 今回は使わないが残しておく

    override init() {
        super.init()
        loadAd() // 初期化時に広告をプリロードしておく
    }

    func loadAd() {
        print("💡 InterstitialAdManager: ロード開始...")
        let request = Request()
        // 既存の広告があれば、新しいロードの前にnilにリセット
        self.interstitial = nil // 新しいロードを開始する前に既存の広告をクリア
        InterstitialAd.load(
            with: "ca-app-pub-3940256099942544/4411468910",
            request: request,
            completionHandler: { [weak self] ad, error in
                guard let self = self else { return }
                if let error = error {
                    print("❌ Interstitial ad failed to load: \(error.localizedDescription)")
                    // ロード失敗時はinterstitialはnilのまま
                    return
                }
                self.interstitial = ad
                self.interstitial?.fullScreenContentDelegate = self
                print("✅ Interstitial ad loaded")
            }
        )
    }

    // 広告表示後に実行するクロージャを受け取るように変更
    // 修正: from rootViewController を再度追加
    func showAd(from rootViewController: UIViewController,
                onPresented: @escaping () -> Void, // 今回は使わないが、将来的に必要なら利用
                onDismissed: @escaping () -> Void) {
        
        // 広告が準備できていない場合は、すぐにonDismissedを呼んでロードを試みる
        guard let ad = interstitial else {
            print("⚠️ Interstitial ad not ready for presentation. Proceeding without showing ad.")
            onDismissed()
            loadAd() // 次の表示のために広告をロード
            return
        }
        
        self.onAdImpressionRecordedCompletion = onPresented // これを呼び出すのは adDidRecordImpression
        self.onAdDismissedCompletion = onDismissed

        // 広告を提示
        ad.present(from: rootViewController)
        // ここでは interstitial を nil にせず、デリゲートメソッドが呼ばれるまで待つ
    }

    // MARK: - FullScreenContentDelegate

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("✅ Interstitial ad impression recorded")
        onAdImpressionRecordedCompletion?()
        onAdImpressionRecordedCompletion = nil
        // 広告が正常に表示され、インプレッションが記録されたら、ここで次の広告をロードするキューに入れる
        // loadAd() は adDidDismissFullScreenContent で呼ぶためここでは呼ばない
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("ℹ️ Interstitial ad dismissed")
        self.interstitial = nil // 広告が閉じられたのでクリア
        loadAd() // 次の表示のために新しい広告をプリロード

        onAdDismissedCompletion?() // 保持していた完了クロージャを実行
        onAdDismissedCompletion = nil
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ Failed to present interstitial ad: \(error.localizedDescription)")
        self.interstitial = nil // 広告の表示に失敗したのでクリア
        loadAd() // 次の表示のために新しい広告をプリロード

        onAdDismissedCompletion?() // 保持していた完了クロージャを実行
        onAdDismissedCompletion = nil
    }
}

