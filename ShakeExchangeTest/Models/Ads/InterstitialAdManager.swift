//
//  InterstitialAdManager.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/16.
//

import GoogleMobileAds
import SwiftUI

@MainActor
class InterstitialAdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    private var interstitial: InterstitialAd? // InterstitialAd は GoogleMobileAds SDK の InterstitialAd
    
    private var onAdDismissedCompletion: (() -> Void)?
    private var onAdImpressionRecordedCompletion: (() -> Void)? // 今回は使わないが残しておく
    @Published var isAdLoaded: Bool = false

    override init() {
        super.init()
        loadAd() // 初期化時に広告をプリロードしておく
    }

    func loadAd() {
        print("💡 InterstitialAdManager: ロード開始...")
        let request = Request()
        // MARK: - 堅牢性向上: 新しいロードを開始する前に既存の広告をクリア
        self.interstitial = nil
        InterstitialAd.load(
            with: "ca-app-pub-3940256099942544/4411468910",
            request: request,
            completionHandler: { [weak self] ad, error in
                guard let self = self else { return }
                // MARK: - 堅牢性向上: ロード失敗時のnilクリア
                if let error = error {
                    print("❌ Interstitial ad failed to load: \(error.localizedDescription)")
                    self.interstitial = nil // ロード失敗時はinterstitialをnilに保つ
                    return
                }
                self.interstitial = ad
                self.interstitial?.fullScreenContentDelegate = self
                self.isAdLoaded = (ad != nil)
                print("✅ Interstitial ad loaded")
            }
        )
    }

    func showAd(from rootViewController: UIViewController,
                onPresented: @escaping () -> Void,
                onDismissed: @escaping () -> Void) {
        
        // MARK: - 堅牢性向上: 広告が準備できていない場合の早期終了とロード試行
        guard let ad = interstitial else {
            print("⚠️ Interstitial ad not ready for presentation. Proceeding without showing ad. Trying to load next ad.")
            onDismissed() // 広告が表示できない場合はonDismissedをすぐに呼ぶ
            loadAd() // 次の表示のために広告をロード
            return
        }
        
        self.onAdImpressionRecordedCompletion = onPresented
        self.onAdDismissedCompletion = onDismissed

        DispatchQueue.main.async {
            ad.present(from: rootViewController)
        }
        // ここでは interstitial を nil にせず、デリゲートメソッドが呼ばれるまで待つ
    }

    // MARK: - FullScreenContentDelegate

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("✅ Interstitial ad impression recorded")
        onAdImpressionRecordedCompletion?()
        // MARK: - 堅牢性向上: クロージャは一度呼ばれたらクリア
        onAdImpressionRecordedCompletion = nil
        // 広告が正常に表示され、インプレッションが記録されたら、ここで次の広告をロードするキューに入れる
        // loadAd() は adDidDismissFullScreenContent で呼ぶためここでは呼ばない
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("ℹ️ Interstitial ad dismissed")
        self.interstitial = nil
        isAdLoaded = false
        loadAd() // 次の表示のために新しい広告をプリロード

        onAdDismissedCompletion?()
        // MARK: - 堅牢性向上: クロージャは一度呼ばれたらクリア
        onAdDismissedCompletion = nil
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ Failed to present interstitial ad: \(error.localizedDescription)")
        self.interstitial = nil
        isAdLoaded = false
        loadAd() // 次の表示のために新しい広告をプリロード

        onAdDismissedCompletion?()
        // MARK: - 堅牢性向上: クロージャは一度呼ばれたらクリア
        onAdDismissedCompletion = nil
    }
}
