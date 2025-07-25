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
    // id の初期化を削除し、var で宣言するだけにするか、
    // 以下のように引数として受け取れるイニシャライザを追加する
    public var id: UUID // 明示的に外部から設定できるようにする
    public var userUUID: String
    public var friendUUID: String
    public var outerImage: String
    public var innerImage: String
    public var date: String
    public var note: String
    public var rotation: Double
    public var pinColor: Color

    public var ownerName: String?
    public var ownerIcon: String?
    public var friendNameAtCapture: String?
    public var friendIconAtCapture: String?

    public var viewerUUIDs: [String]?

    // 新しいイニシャライザを追加、または既存のイニシャライザに id を追加
    public init(id: UUID = UUID(), userUUID: String, friendUUID: String, outerImage: String, innerImage: String, date: String, note: String, rotation: Double, pinColor: Color, ownerName: String? = nil, ownerIcon: String? = nil, friendNameAtCapture: String? = nil, friendIconAtCapture: String? = nil, viewerUUIDs: [String]? = nil) {
        self.id = id // 受け取った id を設定
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

