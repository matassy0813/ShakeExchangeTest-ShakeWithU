//
//  AdView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/16.
//

import SwiftUI
import GoogleMobileAds

struct AdView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> NativeAdView {
        let nativeAdView = NativeAdView()

        let headlineView = UILabel()
        headlineView.font = UIFont.boldSystemFont(ofSize: 16)
        headlineView.numberOfLines = 2
        nativeAdView.headlineView = headlineView

        let mediaView = MediaView()
        mediaView.contentMode = .scaleAspectFill
        mediaView.clipsToBounds = true
        nativeAdView.mediaView = mediaView

        let stack = UIStackView(arrangedSubviews: [headlineView, mediaView])
        stack.axis = .vertical
        stack.spacing = 8

        nativeAdView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor)
        ])

        let adLoader = AdLoader(
            adUnitID: "ca-app-pub-3940256099942544/3986624511", // ← テスト用ユニットID
            rootViewController: UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.windows.first?.rootViewController }
                .first,
            adTypes: [.native],
            options: nil
        )

        context.coordinator.adView = nativeAdView
        adLoader.delegate = context.coordinator
        adLoader.load(Request())

        return nativeAdView
    }

    func updateUIView(_ uiView: NativeAdView, context: Context) {}

    class Coordinator: NSObject, NativeAdLoaderDelegate {
        var adView: NativeAdView?

        func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
            print("✅ ネイティブ広告を取得しました")
            adView?.nativeAd = nativeAd
            if let headline = adView?.headlineView as? UILabel {
                headline.text = nativeAd.headline
            }
        }

        func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
            print("❌ 広告の取得に失敗: \(error.localizedDescription)")
        }
    }
}
