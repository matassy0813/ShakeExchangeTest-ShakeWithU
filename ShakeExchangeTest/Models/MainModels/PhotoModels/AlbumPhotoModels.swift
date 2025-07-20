//
//  AlbumPhotoModels.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/23.
//

import SwiftUI
import Foundation // CGFloatのために必要

// カラーのCodable対応
extension Color: Codable {
    private enum CodingKeys: String, CodingKey {
        case red, green, blue, alpha
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0

        // プラットフォームに応じてUIColorまたはNSColorを使用
        #if canImport(UIKit)
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #elseif canImport(AppKit)
        NSColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #endif

        try container.encode(red, forKey: .red)
        try container.encode(green, forKey: .green)
        try container.encode(blue, forKey: .blue)
        try container.encode(alpha, forKey: .alpha)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let red = try container.decode(CGFloat.self, forKey: .red)
        let green = try container.decode(CGFloat.self, forKey: .green)
        let blue = try container.decode(CGFloat.self, forKey: .blue)
        let alpha = try container.decode(CGFloat.self, forKey: .alpha)

        self = Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

// MARK: - Album Photo Model
public struct AlbumPhoto: Identifiable, Hashable, Codable {
    public var id = UUID()
    public var userUUID: String // 写真を撮影したユーザーのUUID
    public var friendUUID: String // 写真に写っている友達のUUID
    public var outerImage: String // Storageパス
    public var innerImage: String // Storageパス
    public var date: String
    public var note: String
    public var rotation: Double
    public var pinColor: Color // ColorがCodableなので、特別な実装は不要

    // フィード表示のために、撮影者と相手のアイコン・名前も保持できるように拡張
    // これらはAlbumPhotoのメタデータとしてFirestoreに保存されることを想定
    public var ownerName: String? // 撮影者の名前
    public var ownerIcon: String? // 撮影者のアイコンパス
    public var friendNameAtCapture: String? // 撮影時の友達の名前
    public var friendIconAtCapture: String? // 撮影時の友達のアイコンパス

    // 追加: この写真を見ることができるユーザーのUUIDs
    public var viewerUUIDs: [String]?

    public init(userUUID: String, friendUUID: String, outerImage: String, innerImage: String, date: String, note: String, rotation: Double, pinColor: Color, ownerName: String? = nil, ownerIcon: String? = nil, friendNameAtCapture: String? = nil, friendIconAtCapture: String? = nil, viewerUUIDs: [String]? = nil) {
        self.userUUID = userUUID
        self.friendUUID = friendUUID
        self.outerImage = outerImage
        self.innerImage = innerImage
        self.date = date
        self.note = note
        self.rotation = rotation
        self.pinColor = pinColor
        self.ownerName = ownerName
        self.ownerIcon = ownerIcon
        self.friendNameAtCapture = friendNameAtCapture
        self.friendIconAtCapture = friendIconAtCapture
        self.viewerUUIDs = viewerUUIDs
    }
}

