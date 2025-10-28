//
//  FeedItemView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//
import SwiftUI
import FirebaseAuth
import Firebase
import FirebaseFirestore // ADDED for reporting

struct FeedItemView: View {
    let feedEntry: FeedEntry // FeedEntry全体を受け取る
    // photoはfeedEntry.photoと重複するため削除
    
    @State private var isLiked = false
    @State private var outerImage: UIImage? = nil
    @State private var isLoadingImage: Bool = true
    @State private var showingReportActionSheet = false
    @State private var isReporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // MARK: 1. ユーザー行 (プロフィール遷移のみ) - 元のシンプルな構造に戻す
            NavigationLink(
                destination: FriendProfileView(friend: feedEntry.friend) // 友達のプロフィールへ遷移
            ) {
                HStack {
                    // 撮影者のアイコン
                    if let uiImage = loadUserIcon(named: feedEntry.ownerIcon) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                            .foregroundColor(.gray)
                    }

                    // 撮影者の名前
                    Text(feedEntry.ownerName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    // 相手のアイコンと名前 (写真に写っている友達)
                    if let friendNameAtCapture = feedEntry.photo.friendNameAtCapture,
                       let friendIconAtCapture = feedEntry.photo.friendIconAtCapture {
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                        if let uiImage = loadUserIcon(named: friendIconAtCapture) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())
                                .foregroundColor(.gray)
                        }
                        Text(friendNameAtCapture)
                            .font(.subheadline)
                    }

                    Spacer()
                    // 🚨 通報ボタンはここから削除 🚨
                }
            }
            .buttonStyle(PlainButtonStyle())

            // 画像部分（outerカメラをfeedに表示）
            if isLoadingImage {
                ProgressView()
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
            } else if let image = outerImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 250)
                    .clipped()
                    .cornerRadius(12)
            } else {
                Image(systemName: "photo") // 画像がない場合のプレースホルダー
                    .resizable()
                    .scaledToFit()
                    .frame(height: 250)
                    .foregroundColor(.gray)
                    .cornerRadius(12)
            }
            
            // MARK: 2. アクションバー（いいねボタンと通報ボタン）
            HStack {
                // いいねボタン
                Button(action: {
                    withAnimation {
                        isLiked.toggle()
                    }
                }) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundColor(isLiked ? .red : .primary)
                        .font(.title3)
                }
                
                // 通報ボタンをいいねボタンの隣に移動 (長押しジェスチャで発動)
                Button(action: {}) { // ダミーのアクション
                    Image(systemName: "flag")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5) // 長押しで通報を開始
                        .onEnded { _ in
                            showingReportActionSheet = true
                        }
                )
                
                Spacer()
            }

            // 日付
            Text(feedEntry.photo.date)
                .font(.caption)
                .foregroundColor(.gray)
            
            // メモ
            if !feedEntry.photo.note.isEmpty {
                Text(feedEntry.photo.note)
                    .font(.caption)
                    .foregroundColor(.black)
            }

        }
        .padding(.vertical)
        .onAppear {
            loadImageFromStorage()
        }
        .onDisappear {
            self.outerImage = nil
            self.isLoadingImage = true
        }
        .onChange(of: feedEntry.photo.outerImage) { _ in
            loadImageFromStorage() // パスが変更されたら画像を再ロード
        }
        // 通報確認ダイアログ
        .confirmationDialog(
            Text("投稿の報告"),
            isPresented: $showingReportActionSheet,
            titleVisibility: .visible
        ) {
            Button(isReporting ? "送信中..." : "不適切なコンテンツとして報告する", role: .destructive) {
                if !isReporting {
                    Task { await reportFeedContent() }
                }
            }
            .disabled(isReporting)

            Button("キャンセル", role: .cancel) {}
        }
    }

    // MARK: - Firebase Storageから画像をダウンロード
    private func loadImageFromStorage() {
        isLoadingImage = true
        outerImage = nil // 古い画像をクリア
        Task {
            var loadedImage: UIImage?
            if let currentUserUUID = Auth.auth().currentUser?.uid {
                if currentUserUUID == feedEntry.photo.userUUID { // Use feedEntry.photo
                    // 自分の写真 → 通常の画像取得 (async version)
                    loadedImage = await AlbumManager.shared.downloadImage(from: feedEntry.photo.outerImage)
                } else {
                    // 友達の写真 → CloudFunctions経由で取得 (completion handler version)
                    // Use a CheckedContinuation to bridge completion handler to async/await
                    loadedImage = await withCheckedContinuation { continuation in
                        AlbumManager.shared.downloadImageWithSignedURL(photoId: feedEntry.photo.id.uuidString) { image in
                            continuation.resume(returning: image)
                        }
                    }
                }
            }
            await MainActor.run { // MainActorでUIを更新
                self.outerImage = loadedImage
                self.isLoadingImage = false
            }

//            DispatchQueue.main.async {
//                self.outerImage = loadedImage
//                self.isLoadingImage = false
//            }
        }
    }

    // MARK: - アイコン画像読み込みヘルパー
    private func loadUserIcon(named filename: String?) -> UIImage? {
        guard let filename = filename else { return nil }
        // 1. アセットカタログからの読み込みを試行
        if let image = UIImage(named: filename) {
            return image
        }
        // 2. ドキュメントディレクトリからの読み込みを試行
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
    
    // UGC Moderation: New function for reporting feed content
    private func reportFeedContent() async {
        isReporting = true
        defer {
            DispatchQueue.main.async {
                self.isReporting = false
            }
        }
        print("[FeedItemView] 🚨 投稿報告リクエスト: PhotoID=\(feedEntry.photo.id.uuidString) Owner=\(feedEntry.photo.userUUID)")
        
        let db = Firestore.firestore()
        let reportData: [String: Any] = [
            "reporterId": Auth.auth().currentUser?.uid ?? "unknown",
            "reportedContentId": feedEntry.photo.id.uuidString,
            "reportedContentOwnerId": feedEntry.photo.userUUID,
            "reason": "Inappropriate photo or note",
            "timestamp": Timestamp(date: Date()),
            "status": "pending"
        ]
        
        do {
            try await db.collection("reports").addDocument(data: reportData)
            print("[FeedItemView] ✅ 報告ドキュメント作成成功。")
            await MainActor.run {
                // 報告成功のフィードバックとしてシートを閉じる
                self.showingReportActionSheet = false
                // NOTE: deferブロックがisReportingをfalseに戻す
            }
        } catch {
            print("[FeedItemView] ❌ 報告処理失敗: \(error.localizedDescription)")
            // NOTE: deferブロックがisReportingをfalseに戻す
        }
    }
}
