//
//  FeedManager.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//

import Foundation
import SwiftUI // AlbumPhoto, Friend のために必要
import FirebaseFirestore // Firestoreをインポート
import FirebaseAuth // FirebaseAuthをインポート
import Combine // Combineフレームワークをインポート

// MARK: - フィードのエントリを表す構造体
// フィードに表示される各アイテムのデータ構造
struct FeedEntry: Identifiable, Hashable {
    let id = UUID() // ユニークなID
    let photo: AlbumPhoto // 表示する写真のデータ
    let friend: Friend // この写真に関連する友達のデータ (自分が設定したニックネームなど)
    // 撮影者（owner）の情報も直接FeedEntryに持たせることで、表示が容易になる
    let ownerName: String
    let ownerIcon: String
}

// FeedEntryか広告かを区別するための列挙型
enum FeedContent: Identifiable, Hashable {
    case entry(FeedEntry)
    case ad(UUID)

    var id: UUID {
        switch self {
        case .entry(let entry): return entry.id
        case .ad(let id): return id
        }
    }
}


class FeedManager: ObservableObject {
    static let shared = FeedManager()

    @Published var feed: [FeedContent] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var db: Firestore!
    private var auth: Auth!
    private var cancellables = Set<AnyCancellable>()

    private init() {
        db = Firestore.firestore()
        auth = Auth.auth()

        // AuthManagerの認証状態変更を監視し、フィードのロードをトリガー
        AuthManager.shared.$isAuthenticated
            .combineLatest(FriendManager.shared.$friends) // 友達リストの変更も監視
            .sink { [weak self] isAuthenticated, friends in
                guard let self = self else { return }
                if isAuthenticated, let userId = AuthManager.shared.userId {
                    print("[FeedManager] ✅ AuthManagerから認証通知受信 or FriendManagerから友達リスト更新通知受信。フィードをロードします。")
                    Task {
                        await self.loadFeed(for: userId, friends: friends)
                    }
                } else {
                    print("[FeedManager] ℹ️ 未認証または友達リストが空のため、フィードをクリアします。")
                    DispatchQueue.main.async {
                        self.feed = []
                        self.isLoading = false
                        self.errorMessage = nil
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - フィードのロード
    /// 現在のユーザーのフィードをFirestoreからロードします。
    /// フィードは、自分の友達が撮影した写真（自分との写真を含む）と、
    /// 自分が撮影した友達との写真で構成されます。
    func loadFeed(for userId: String, friends: [Friend]) async {
        self.isLoading = true
        self.errorMessage = nil
        var fetchedFeedEntries: [FeedEntry] = []

        do {
            // MARK: 1. 自分が撮影した友達との写真をロード
            let myPhotosWithFriends = try await AlbumManager.shared.loadMyAlbumPhotos()
            for photo in myPhotosWithFriends {
                // photo.friendUUID が自分の友達リストに存在するか確認
                if let friend = friends.first(where: { $0.uuid == photo.friendUUID }) {
                    fetchedFeedEntries.append(
                        FeedEntry(
                            photo: photo,
                            friend: friend, // 自分が設定したニックネームを持つFriendオブジェクト
                            ownerName: photo.ownerName ?? "Unknown", // 自分の名前
                            ownerIcon: photo.ownerIcon ?? "profile_startImage" // 自分のアイコン
                        )
                    )
                }
            }
            print("[FeedManager] ✅ 自分が撮影した友達との写真ロード完了: \(myPhotosWithFriends.count)件")


            // MARK: 2. 友達が撮影した自分との写真をロード (高度な機能 - 現時点ではコメントアウト)
            // この機能は、相手のFirestoreのアルバムコレクションへのアクセス権限（セキュリティルールで許可）と、
            // 相手のアルバムから自分との写真をフィルタリングするロジックが必要になります。
            // 現状のセキュリティルールでは、他のユーザーのアルバム全体へのアクセスは許可されていません。
            // もしこの機能を実装する場合、Firestoreルールをさらに柔軟にするか、
            // Cloud Functions を使ってサーバーサイドでデータを取得・集約する必要があります。
            /*
            for friend in friends {
                // 友達の公開アルバムから、自分との写真をロードするロジック（要Firestoreルール拡張）
                // 例: let friendPhotosOfMe = try await AlbumManager.shared.loadPhotosFromFriendAlbum(friendId: friend.uuid, forUser: userId)
                // for photo in friendPhotosOfMe {
                //     fetchedFeedEntries.append(
                //         FeedEntry(
                //             photo: photo,
                //             friend: friend, // 相手の自己申告名を持つFriendオブジェクト
                //             ownerName: photo.ownerName ?? "Unknown", // 相手の名前
                //             ownerIcon: photo.ownerIcon ?? "profile_startImage" // 相手のアイコン
                //         )
                //     )
                // }
            }
            */

            // MARK: 3. 日付の新しい順にソートしてフィードを更新
            DispatchQueue.main.async {
                // FeedEntryをFeedContentに変換して広告を挿入
                let sortedEntries = fetchedFeedEntries.sorted(by: { $0.photo.date > $1.photo.date })

                var feedWithAds: [FeedContent] = []
                for (index, entry) in sortedEntries.enumerated() {
                    feedWithAds.append(.entry(entry))
                    // 3つに1つ広告を挿入（任意のタイミングで変更可）
                    if (index + 1) % 3 == 0 {
                        feedWithAds.append(.ad(UUID()))
                    }
                }

                self.feed = feedWithAds
                self.isLoading = false
                print("[FeedManager] ✅ フィードロード完了（広告込み）: \(self.feed.count)件")
            }

        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                print("[FeedManager] ❌ フィードロード失敗: \(error.localizedDescription)")
            }
        }
        
        
    }
}
