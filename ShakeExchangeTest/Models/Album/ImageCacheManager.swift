//
//  ImageCacheManager.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/08/15.
//

// ImageCacheManager.swift (新規ファイル)

import UIKit

class ImageCacheManager {
    static let shared = ImageCacheManager()
    private let imageCache = NSCache<NSString, UIImage>()

    private init() {
        // キャッシュの上限を設定
        imageCache.countLimit = 100 // 50枚から100枚に増加
        imageCache.totalCostLimit = 1024 * 1024 * 250 // 100MBから250MBに増加 <-- 【修正】
    }

    // キャッシュに画像を保存
    func set(_ image: UIImage, for key: String) {
        imageCache.setObject(image, forKey: key as NSString)
    }

    // キャッシュから画像を取得
    func get(for key: String) -> UIImage? {
        return imageCache.object(forKey: key as NSString)
    }
}
