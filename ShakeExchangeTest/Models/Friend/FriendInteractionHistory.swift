//
//  FriendInteractionHistory.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/08/30.
//

// FriendInteractionHistory.swift
// 変更・追記点のみ抜粋
import Foundation
import CoreLocation
import FirebaseFirestore

extension FriendManager {

    // ★ 後方互換（配列のみ返す）：内部で1ページだけ呼ぶ
    func fetchInteractions(for friendUUID: String, limit: Int = 30) async throws -> [FriendInteraction] {
        let (items, _) = try await fetchInteractionsPage(for: friendUUID, pageSize: limit, startAfter: nil)
        return items
    }

    // ★ 新規：ページング対応（配列 + 次ページカーソル）
    func fetchInteractionsPage(for friendUUID: String,
                               pageSize: Int = 10,
                               startAfter: DocumentSnapshot?) async throws -> ([FriendInteraction], DocumentSnapshot?) {
        guard let userId = AuthManager.shared.userId else {
            throw NSError(domain: "FriendManager", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let friendDoc = db.collection("users")
            .document(userId)
            .collection("friends")
            .document(friendUUID)

        // 1) interactions サブコレ（新しい順）をページング取得
        var items: [FriendInteraction] = []
        var nextCursor: DocumentSnapshot? = nil

        do {
            var query: Query = friendDoc.collection("interactions")
                .order(by: "timestamp", descending: true)
                .limit(to: pageSize)

            if let cursor = startAfter {
                query = query.start(afterDocument: cursor)
            }

            let snap = try await query.getDocuments()

            for doc in snap.documents {
                let data = doc.data()
                let ts = parseDate(from: data["timestamp"])

                if let (lat, lon) = parseLocation(from: data) {
                    items.append(
                        FriendInteraction(
                            id: doc.documentID,
                            friendUUID: friendUUID,
                            timestamp: ts ?? Date(),
                            latitude: lat,
                            longitude: lon,
                            kind: data["kind"] as? String,
                            note: data["note"] as? String
                        )
                    )
                }
            }

            // 次ページ用カーソル
            nextCursor = snap.documents.last
        } catch {
            // サブコレ読み取りエラーでも後段フォールバックへ
            print("[FriendManager] interactions read error: \(error.localizedDescription)")
        }

        // 1件以上取れたらそのまま返す
        if !items.isEmpty {
            return (items, nextCursor)
        }

        // 2) サブコレ空：最初のページに限り friend 本体から1件フォールバック
        if startAfter == nil {
            let friendSnap = try await friendDoc.getDocument()
            if friendSnap.exists, let data = friendSnap.data() {
                var latLon: (Double, Double)?
                if let gp = data["lastLocation"] as? GeoPoint {
                    latLon = (gp.latitude, gp.longitude)
                } else {
                    latLon = parseLocation(from: data)
                }

                let ts = parseDate(from: data["lastInteracted"])
                    ?? parseDate(from: data["addedDate"])
                    ?? parseDate(from: data["lastStreakDate"])
                    ?? Date()

                if let (lat, lon) = latLon {
                    let fallback = FriendInteraction(
                        id: "fallback-\(friendUUID)",
                        friendUUID: friendUUID,
                        timestamp: ts,
                        latitude: lat,
                        longitude: lon,
                        kind: "lastKnown",
                        note: "最後に記録された交流地点（フォールバック）"
                    )
                    return ([fallback], nil)
                }
            }
        }

        return ([], nil)
    }
}

// parseDate / parseLocation は既存のまま利用（省略）


// MARK: - Helpers

/// 複数の可能性に対応して Date を生成
private func parseDate(from any: Any?) -> Date? {
    if let d = any as? Date { return d }

    // Firestore Timestamp
    if let ts = any as? Timestamp { return ts.dateValue() }

    // 数値: UNIX秒/ミリ秒
    if let n = any as? NSNumber {
        let v = n.doubleValue
        return Date(timeIntervalSince1970: v > 10_000_000_000 ? v / 1000.0 : v)
    }

    // 文字列: ISO8601 / "yyyy-MM-dd"
    if let s = any as? String {
        // ISO8601
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return d }

        // "yyyy-MM-dd"
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.dateFormat = "yyyy-MM-dd"
        if let d = df.date(from: s) { return d }
    }
    return nil
}

/// 位置を柔軟にパース: GeoPoint / {latitude,longitude} / location(GeoPoint) / coords(dict) など
private func parseLocation(from data: [String: Any]) -> (Double, Double)? {
    // 1) そのまま GeoPoint
    if let gp = data["location"] as? GeoPoint {
        return (gp.latitude, gp.longitude)
    }
    if let gp = data["geoPoint"] as? GeoPoint {
        return (gp.latitude, gp.longitude)
    }
    if let gp = data["lastLocation"] as? GeoPoint {
        return (gp.latitude, gp.longitude)
    }

    // 2) 分離フィールド
    if let lat = data["latitude"] as? Double, let lon = data["longitude"] as? Double {
        return (lat, lon)
    }
    if let lat = (data["lat"] as? NSNumber)?.doubleValue,
       let lon = (data["lon"] as? NSNumber)?.doubleValue {
        return (lat, lon)
    }

    // 3) 辞書
    if let dict = data["coords"] as? [String: Any] {
        if let lat = dict["latitude"] as? Double, let lon = dict["longitude"] as? Double {
            return (lat, lon)
        }
        if let lat = (dict["lat"] as? NSNumber)?.doubleValue,
           let lon = (dict["lon"] as? NSNumber)?.doubleValue {
            return (lat, lon)
        }
    }

    return nil
}
