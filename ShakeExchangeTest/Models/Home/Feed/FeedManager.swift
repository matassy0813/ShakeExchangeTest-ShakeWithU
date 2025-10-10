//
//  FeedManager.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//
import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

struct FeedEntry: Identifiable, Hashable {
    let id = UUID()
    let photo: AlbumPhoto
    let friend: Friend
    let ownerName: String
    let ownerIcon: String
}

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
        auth = FirebaseAuth.Auth.auth()

        AuthManager.shared.$isAuthenticated
            .combineLatest(FriendManager.shared.$friends)
            .sink { [weak self] isAuthenticated, friends in
                guard let self = self else { return }
                // MARK: - 堅牢性向上: AuthManager.shared.userId を使用し、nilチェックを強化
                if isAuthenticated, let userId = AuthManager.shared.userId {
                    print("[FeedManager] ✅ AuthManagerから認証通知受信 or FriendManagerから友達リスト更新通知受信。フィードをロードします。User ID: \(userId)")
                    // MARK: - 堅牢性向上: friendsが空でもロードを試みる（新規ユーザーの場合など）
                    Task {
                        await self.loadFeed(for: userId, friends: friends)
                    }
                } else {
                    print("[FeedManager] ℹ️ 未認証またはユーザーIDが取得できないため、フィードをクリアします。")
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
    func loadFeed(for userId: String, friends: [Friend]) async {
        // MARK: - 堅牢性向上: 多重ロード防止
        guard !isLoading else {
            print("[FeedManager] ⚠️ 既にフィードロード中のためスキップ。")
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        var allFeedPhotos: [AlbumPhoto] = []

        do {
            // MARK: 1. 自分が撮影した友達との写真をロード
            let (myPhotosWithFriends, _) = try await AlbumManager.shared.loadMyAlbumPhotos(limit: 15)
            allFeedPhotos.append(contentsOf: myPhotosWithFriends)
            print("[FeedManager] ✅ 自分が撮影した友達との写真ロード完了: \(myPhotosWithFriends.count)件")

            // MARK: 2. 共有フィード写真（友達が撮影した自分との写真など）をロード
            // 【修正】初期ロードの枚数を大幅に削減 (30 -> 15)
            let (sharedPhotos, lastSnapshot) = try await AlbumManager.shared.loadSharedFeedPhotos(for: userId, limit: 15)
            allFeedPhotos.append(contentsOf: sharedPhotos)
            print("[FeedManager] ✅ 共有フィード写真ロード完了: \(sharedPhotos.count)件")

            // MARK: 3. 全ての写真を日付の新しい順にソートし、FeedEntryに変換
            // 重複を排除 (UUIDでフィルタリング)
            let uniquePhotos = Dictionary(grouping: allFeedPhotos, by: { $0.id }).values.compactMap { $0.first }

            let sortedPhotos = uniquePhotos.sorted(by: { $0.date > $1.date })

            var fetchedFeedEntries: [FeedEntry] = []
            for photo in sortedPhotos {
                let ownerName: String
                let ownerIcon: String
                
                if photo.userUUID == userId {
                    // 自分が撮影した写真
                    ownerName = await ProfileManager.shared.currentUser.name
                    ownerIcon = await ProfileManager.shared.currentUser.icon
                } else if let friend = friends.first(where: { $0.uuid == photo.userUUID }) {
                    // 友達が撮影した写真（photo.userUUID は友達のUUID）
                    ownerName = photo.ownerName ?? friend.nickname // photo.ownerName を優先
                    ownerIcon = photo.ownerIcon ?? friend.icon // photo.ownerIcon を優先
                } else {
                    // 撮影者が不明な場合（データ不整合など）
                    ownerName = photo.ownerName ?? "Unknown User"
                    // MARK: - 堅牢性向上: 不明な場合のアイコンをシステムアイコンなどにフォールバック
                    ownerIcon = photo.ownerIcon ?? "person.circle.fill" // システムアイコン名
                    print("[FeedManager] ⚠️ 撮影者UUID (\(photo.userUUID)) が友達リストに見つかりません。")
                }

                if let displayFriend = friends.first(where: { $0.uuid == photo.friendUUID }) {
                    fetchedFeedEntries.append(
                        FeedEntry(
                            photo: photo,
                            friend: displayFriend,
                            ownerName: ownerName,
                            ownerIcon: ownerIcon
                        )
                    )
                } else {
                    // MARK: - 堅牢性向上: photo.friendUUID が友達リストに見つからない場合
                    print("[FeedManager] ⚠️ 写真に写っている友達UUID (\(photo.friendUUID)) が友達リストに見つかりません。ダミーデータを使用します。")
                    let dummyFriend = Friend(
                        uuid: photo.friendUUID,
                        name: photo.friendNameAtCapture ?? "Unknown Friend",
                        nickname: photo.friendNameAtCapture ?? "Unknown Friend",
                        icon: photo.friendIconAtCapture ?? "person.circle.fill", // システムアイコン名
                        description: "", link: "", addedDate: "", lastInteracted: "", challengeStatus: 0, recentPhotos: [], encounterCount: nil, streakCount: nil
                    )
                    fetchedFeedEntries.append(
                        FeedEntry(
                            photo: photo,
                            friend: dummyFriend,
                            ownerName: ownerName,
                            ownerIcon: ownerIcon
                        )
                    )
                }
            }
            
            DispatchQueue.main.async {
                var feedWithAds: [FeedContent] = []
                for (index, entry) in fetchedFeedEntries.enumerated() {
                    feedWithAds.append(.entry(entry))
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
