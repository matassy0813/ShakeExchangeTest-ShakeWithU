//
//  UserModels.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/23.
//

import SwiftUI
import Foundation // UUIDのために必要

// MARK: - 共通のプロファイルデータプロトコル
protocol ProfileData: Codable, Identifiable {
    var uuid: String { get set }
    var name: String { get set }
    var description: String { get set }
    var icon: String { get set } // ファイル名
    var link: String { get set }
    var challengeStatus: Int { get set }
    var recentPhotos: [AlbumPhoto] { get set }
    var lastLoginDate: Date? { get set } // ★追加: 最終ログイン日時
}

// MARK: - Current User Model (自身のユーザー情報)
public struct CurrentUser: ProfileData {
    public var id: UUID { UUID(uuidString: uuid) ?? UUID() } // Identifiable準拠
    public var uuid: String
    public var name: String
    public var description: String
    public var icon: String
    public var link: String
    public var challengeStatus: Int
    public var recentPhotos: [AlbumPhoto]
    public var lastLoginDate: Date? // ★追加

    // デフォルトイニシャライザ
    public init(uuid: String, name: String, description: String, icon: String, link: String, challengeStatus: Int, recentPhotos: [AlbumPhoto], lastLoginDate: Date? = nil) {
        self.uuid = uuid
        self.name = name
        self.description = description
        self.icon = icon
        self.link = link
        self.challengeStatus = challengeStatus
        self.recentPhotos = recentPhotos
        self.lastLoginDate = lastLoginDate // ★追加
    }
}
