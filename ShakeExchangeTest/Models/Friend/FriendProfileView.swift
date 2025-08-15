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
            }
            .padding(.vertical)
            .background(Color.black)
        }
        .foregroundColor(.white)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Friend Profile")
        .onAppear {
            loadMyPhotosWithFriend()
        }
        .onChange(of: AuthManager.shared.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                loadMyPhotosWithFriend() // 認証状態が変更されたら再ロード
            }
        }
        .onChange(of: friend.uuid) { _ in
            loadMyPhotosWithFriend() // 友達が変わったら再ロード
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

