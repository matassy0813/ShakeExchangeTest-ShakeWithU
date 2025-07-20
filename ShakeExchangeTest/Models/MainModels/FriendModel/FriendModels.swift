//
//  FriendModels.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/23.
//
import SwiftUI

// MARK: - Friend Model
public struct Friend: Identifiable, Hashable, Codable {
    public let id = UUID()

    public var uuid: String                // 固有ID（インスタ風）
    public var name: String               // 自分が設定した名前
    public var nickname: String           // 相手が設定したニックネーム
    public var icon: String               // プロフィール画像（画像名 or URL）
    public var description: String        // 相手が設定した説明
    public var link: String               // litlinkなどの外部URL
    public var addedDate: String          // 追加した日付
    public var lastInteracted: String     // 最後に交流した日付
    public var challengeStatus: Int       // チャレンジ達成度（未実装）
    public var recentPhotos: [AlbumPhoto] // 最近の5件の写真
    public var encounterCount: Int? = nil // ← 追加
    public var streakCount: Int? = nil // ← 追加
}

let sampleFriends: [Friend] = [
    Friend(
        uuid: "takeshi123",
        name: "たけし",
        nickname: "たけちゃん",
        icon: "sample_icon1",
        description: "ランニング大好き！",
        link: "https://lit.link/takeshi",
        addedDate: "2025-05-01",
        lastInteracted: "2025-05-20",
        challengeStatus: 8,
        recentPhotos: [
            AlbumPhoto(
                userUUID: "myUser001",
                friendUUID: "takeshi123",
                outerImage: "photo1",
                innerImage: "selfie1",
                date: "2025-05-18",
                note: "出会った瞬間",
                rotation: 2,
                pinColor: .red
            ),
            AlbumPhoto(
                userUUID: "myUser001",
                friendUUID: "takeshi123",
                outerImage: "photo2",
                innerImage: "selfie2",
                date: "2025-05-19",
                note: "夜の公園",
                rotation: -3,
                pinColor: .blue
            )
        ]
    ),
    Friend(
        uuid: "yukari456",
        name: "ゆかり",
        nickname: "ゆっきー",
        icon: "sample_icon2",
        description: "カフェと散歩が趣味です☕️",
        link: "https://lit.link/yukari",
        addedDate: "2025-04-28",
        lastInteracted: "2025-05-21",
        challengeStatus: 12,
        recentPhotos: [
            AlbumPhoto(
                userUUID: "myUser001",
                friendUUID: "yukari456",
                outerImage: "photo3",
                innerImage: "selfie3",
                date: "2025-05-20",
                note: "ベンチで休憩",
                rotation: 4,
                pinColor: .green
            )
        ]
    )
]

