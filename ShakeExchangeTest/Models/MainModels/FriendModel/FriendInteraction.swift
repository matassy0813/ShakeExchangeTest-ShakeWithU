//
//  FriendInteraction.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/08/30.
//

import CoreLocation

public struct FriendInteraction: Identifiable, Codable, Hashable {
    public let id: String            // FirestoreドキュメントID
    public let friendUUID: String
    public let timestamp: Date
    public let latitude: Double
    public let longitude: Double
    public let kind: String?         // 例: "shake", "photo", "chat", など
    public let note: String?

    // Firestoreの柔軟な型に対応（ISO文字列/秒・ミリ秒UNIX）
    enum CodingKeys: String, CodingKey {
        case id, friendUUID, timestamp, latitude, longitude, kind, note
    }

    public init(id: String,
                friendUUID: String,
                timestamp: Date,
                latitude: Double,
                longitude: Double,
                kind: String? = nil,
                note: String? = nil) {
        self.id = id
        self.friendUUID = friendUUID
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.kind = kind
        self.note = note
    }
}
