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
        auth = FirebaseAuth.Auth.auth() // FirebaseAuth.Auth.auth() に変更

        // AuthManagerの認証状態変更を監視し、フィードのロードをトリガー
        AuthManager.shared.$isAuthenticated
            .combineLatest(FriendManager.shared.$friends) // 友達リストの変更も監視
            .sink { [weak self] isAuthenticated, friends in
                guard let self = self else { return }
                if isAuthenticated, let userId = FirebaseAuth.Auth.auth().currentUser?.uid { // currentUser?.uid を使用
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
        var allFeedPhotos: [AlbumPhoto] = [] // 自分の写真と共有写真をマージするための配列

        do {
            // MARK: 1. 自分が撮影した友達との写真をロード
            let myPhotosWithFriends = try await AlbumManager.shared.loadMyAlbumPhotos()
            allFeedPhotos.append(contentsOf: myPhotosWithFriends)
            print("[FeedManager] ✅ 自分が撮影した友達との写真ロード完了: \(myPhotosWithFriends.count)件")

            // MARK: 2. 共有フィード写真（友達が撮影した自分との写真など）をロード
            let sharedPhotos = try await AlbumManager.shared.loadSharedFeedPhotos(for: userId)
            allFeedPhotos.append(contentsOf: sharedPhotos)
            print("[FeedManager] ✅ 共有フィード写真ロード完了: \(sharedPhotos.count)件")

            // MARK: 3. 全ての写真を日付の新しい順にソートし、FeedEntryに変換
            // 重複を排除 (例: UUIDでフィルタリング) - ただし、同じ写真が異なるコレクションにある可能性は低い
            let uniquePhotos = Dictionary(grouping: allFeedPhotos, by: { $0.id }).values.compactMap { $0.first }

            let sortedPhotos = uniquePhotos.sorted(by: { $0.date > $1.date }) // 日付でソート

            var fetchedFeedEntries: [FeedEntry] = []
            for photo in sortedPhotos {
                // photo.userUUID が自分 (userId) の場合、ownerName/Icon は自分のプロフィールから取得
                // photo.userUUID が友達の場合、ownerName/Icon は photo の ownerName/Icon を使用
                let ownerName: String
                let ownerIcon: String
                
                if photo.userUUID == userId {
                    // 自分が撮影した写真
                    ownerName = ProfileManager.shared.currentUser.name // 自分のプロフィール名
                    ownerIcon = ProfileManager.shared.currentUser.icon // 自分のアイコン
                } else if let friend = friends.first(where: { $0.uuid == photo.userUUID }) {
                    // 友達が撮影した写真（photo.userUUID は友達のUUID）
                    // ownerName は相手の自己申告名（Friendオブジェクトのnicknameに保存されている場合もある）
                    // photo.ownerName を優先し、なければFriendから取得
                    ownerName = photo.ownerName ?? friend.nickname
                    ownerIcon = photo.ownerIcon ?? friend.icon
                } else {
                    // 撮影者が不明な場合（稀なケース）
                    ownerName = photo.ownerName ?? "Unknown"
                    ownerIcon = photo.ownerIcon ?? "profile_startImage"
                }

                // フィードに表示する友達情報。写真に写っている友達 (friendUUID) を使う
                // 自分の友達リストからその UUID を持つ Friend オブジェクトを探す
                if let displayFriend = friends.first(where: { $0.uuid == photo.friendUUID }) {
                    fetchedFeedEntries.append(
                        FeedEntry(
                            photo: photo,
                            friend: displayFriend, // 自分の友達リストから取得したFriendオブジェクト
                            ownerName: ownerName,
                            ownerIcon: ownerIcon
                        )
                    )
                } else {
                    // もし photo.friendUUID が自分の友達リストに見つからない場合
                    // (例: 友達がアプリをアンインストールした、データ不整合など)
                    // この場合はダミーのFriendオブジェクトを作成するか、FeedEntryに含めないか考慮
                    // 今回は、photo の friendNameAtCapture/friendIconAtCapture を使ってダミーを作成
                    let dummyFriend = Friend(
                        uuid: photo.friendUUID,
                        name: photo.friendNameAtCapture ?? "Unknown Friend",
                        nickname: photo.friendNameAtCapture ?? "Unknown Friend",
                        icon: photo.friendIconAtCapture ?? "profile_startImage",
                        description: "", link: "", addedDate: "", lastInteracted: "", challengeStatus: 0, recentPhotos: [], encounterCount: nil, streakCount: nil // 新しいプロパティも初期化
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
            
            // 広告を挿入してフィードを更新
            DispatchQueue.main.async {
                var feedWithAds: [FeedContent] = []
                for (index, entry) in fetchedFeedEntries.enumerated() {
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
