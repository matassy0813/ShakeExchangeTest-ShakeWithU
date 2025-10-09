//
//  FriendProfileView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//
//
//  FriendProfileView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//
import SwiftUI
import UIKit // UIImage のために必要
import FirebaseFirestore // DocumentSnapshotのために追加

struct FriendProfileView: View {
    let friend: Friend

    // 自分のアルバムから、この友達との写真をロードするためのState
    @State private var myPhotosWithFriend: [AlbumPhoto] = []
    @State private var isLoadingPhotos: Bool = true
    @State private var photoLoadError: String? = nil
    
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss
    
    @State private var interactions: [FriendInteraction] = []
    @State private var isLoadingInteractions: Bool = true
    @State private var interactionsError: String? = nil
    
    // ★ ページング用
    @State private var interactionsCursor: DocumentSnapshot? = nil
    @State private var isLoadingMore: Bool = false
    private let pageSize: Int = 10
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // アイコン・名前・UUID
                FriendHeaderView(friend: friend)

                // 説明文
                if !friend.description.isEmpty {
                    Text(friend.description)
                        .font(.body)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }

                // URL（外部リンク）
                if let url = URL(string: friend.link), UIApplication.shared.canOpenURL(url) { // URLが有効かチェック
                    Link(destination: url) {
                        Text("🔗 \(friend.link)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .underline()
                    }
                }

                // Replaced FriendChallengeView with FriendStreakView
                FriendStreakView(streakCount: friend.streakCount ?? 0) // Pass the streakCount
                
                // RecentPhotosには、最近「自分が」撮影した、相手との写真を表示
                // AlbumManagerからロードした filteredPhotos を渡す
                if isLoadingPhotos {
                    ProgressView("Loading recent photos...")
                        .padding()
                } else if let error = photoLoadError {
                    Text("Error loading recent photos: \(error)")
                        .foregroundColor(.red)
                        .padding()
                } else if myPhotosWithFriend.isEmpty {
                    Text("No photos taken with \(friend.name) yet.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.leading)
                } else {
                    FriendRecentPhotosView(recentPhotos: myPhotosWithFriend.prefix(5).map { $0 }) // 最新5件を渡す
                }

                // アルバムに遷移
                NavigationLink(destination: FriendAlbumView(friendName: friend.name, friendUUID: friend.uuid)) { // photos引数をfriendUUIDに変更
                    Text("📂 アルバムを見る")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                // --- 交流履歴セクション（新規） ---
                VStack(alignment: .leading, spacing: 12) {
                    Text("📍 交流履歴")
                        .font(.headline)
                        .padding(.horizontal)

                    if isLoadingInteractions {
                        ProgressView("Loading interactions...")
                            .padding(.horizontal)
                    } else if let e = interactionsError {
                        Text("Failed to load interactions: \(e)")
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    } else if interactions.isEmpty {
                        Text("この友達との交流履歴はまだありません。")
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(interactions) { item in
                                InteractionRowView(item: item)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color(white: 0.12))
                                    .cornerRadius(10)
                                    .onAppear {
                                        // 最後のセルが出たら次ページ取得
                                        if item.id == interactions.last?.id {
                                            Task { await loadMoreInteractionsIfNeeded() }
                                        }
                                    }
                            }
                            if isLoadingMore {
                                ProgressView("Loading more…")
                                    .padding(.vertical, 8)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(.vertical)
            .background(Color.black)
        }
        .foregroundColor(.white)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Friend Profile")
        .onAppear {
            loadMyPhotosWithFriend()
            Task { await loadInteractions() }   // ← これが無いので永遠にLoadingに
        }
        .onChange(of: AuthManager.shared.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                loadMyPhotosWithFriend() // 認証状態が変更されたら再ロード
                Task { await loadInteractions() }
            }
        }
        .onChange(of: friend.uuid) { _ in
            loadMyPhotosWithFriend() // 友達が変わったら再ロード
            Task { await loadInteractions() }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .accessibilityLabel("友達を削除")
            }
        }
        .confirmationDialog(
            "この友達を本当に削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                Task {
                    await FriendManager.shared.deleteFriend(uuid: friend.uuid)
                    await MainActor.run {
                        dismiss()
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        }

    }
    
    // MARK: - アイコン画像読み込みヘルパー (FriendHeaderViewと同じロジック)
    private func loadUserIcon(named filename: String) -> UIImage? {
        // 1. アセットカタログからの読み込みを試行
        if let image = UIImage(named: filename) {
            return image
        }
        // 2. ドキュメントディレクトリからの読み込みを試行
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
    
    // --- 交流履歴のロード ---
    private func loadInteractions() async {
        await MainActor.run {
            isLoadingInteractions = true
            interactionsError = nil
        }
        do {
            let items = try await FriendManager.shared.fetchInteractions(for: friend.uuid, limit: 30)
            await MainActor.run {
                self.interactions = items
                self.isLoadingInteractions = false
            }
        } catch {
            await MainActor.run {
                self.interactionsError = error.localizedDescription
                self.isLoadingInteractions = false
            }
        }
    }
    
    private func loadFirstPage() async {
        await MainActor.run {
            isLoadingInteractions = true
            interactionsError = nil
            interactions = []
            interactionsCursor = nil
        }
        do {
            let (items, cursor) = try await FriendManager.shared
                .fetchInteractionsPage(for: friend.uuid, pageSize: pageSize, startAfter: nil)
            await MainActor.run {
                interactions = items
                interactionsCursor = cursor
                isLoadingInteractions = false
            }
        } catch {
            await MainActor.run {
                interactionsError = error.localizedDescription
                isLoadingInteractions = false
            }
        }
    }

    private func loadMoreInteractionsIfNeeded() async {
        guard !isLoadingInteractions, !isLoadingMore else { return }
        guard let cursor = interactionsCursor else { return } // もう次が無い

        await MainActor.run { isLoadingMore = true }
        do {
            let (items, next) = try await FriendManager.shared
                .fetchInteractionsPage(for: friend.uuid, pageSize: pageSize, startAfter: cursor)
            await MainActor.run {
                interactions.append(contentsOf: items)
                interactionsCursor = next
                isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                interactionsError = error.localizedDescription
                isLoadingMore = false
            }
        }
    }

    private func reloadAll() async {
        await loadFirstPage()
    }

    // MARK: - 自分のアルバムからこの友達との写真をロード
    private func loadMyPhotosWithFriend() {
        isLoadingPhotos = true
        photoLoadError = nil
        Task {
            do {
                // --- ▼▼▼ ここから修正 ▼▼▼ ---
                // AlbumManagerから返されるタプルのうち、写真の配列のみを受け取る
                // このビューではページングは不要なため、2番目の戻り値(DocumentSnapshot)は無視する
                let (fetchedPhotos, _) = try await AlbumManager.shared.loadFriendAlbumPhotos(friendUUID: friend.uuid)
                
                await MainActor.run {
                    // 日付の新しい順にソート
                    self.myPhotosWithFriend = fetchedPhotos.sorted(by: { $0.date > $1.date })
                    self.isLoadingPhotos = false
                    print("[FriendProfileView] ✅ 自分のアルバムから友達との写真ロード完了: \(self.myPhotosWithFriend.count)件 for \(friend.name)")
                }
                // --- ▲▲▲ ここまで修正 ▲▲▲ ---
            } catch {
                await MainActor.run {
                    self.photoLoadError = error.localizedDescription
                    self.isLoadingPhotos = false
                    print("[FriendProfileView] ❌ 自分のアルバムから友達との写真ロード失敗: \(error.localizedDescription)")
                }
            }
        }
    }
}

