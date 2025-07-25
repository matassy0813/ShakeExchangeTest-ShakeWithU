//
//  FeedItemView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//
import SwiftUI
import FirebaseAuth
import Firebase

struct FeedItemView: View {
    let feedEntry: FeedEntry // FeedEntry全体を受け取る
    // photoはfeedEntry.photoと重複するため削除
    
    @State private var isLiked = false
    @State private var outerImage: UIImage? = nil
    @State private var isLoadingImage: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ユーザー行（撮影者と相手のアイコン・名前を表示）
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
                    Image(systemName: "ellipsis")
                }
            }
            .buttonStyle(PlainButtonStyle()) // これを追加！！

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

            // アクションバー（いいねボタン）
            HStack {
                Button(action: {
                    withAnimation {
                        isLiked.toggle()
                    }
                }) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundColor(isLiked ? .red : .primary)
                        .font(.title3)
                }
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
        .onChange(of: feedEntry.photo.outerImage) { _ in
            loadImageFromStorage() // パスが変更されたら画像を再ロード
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

            DispatchQueue.main.async {
                self.outerImage = loadedImage
                self.isLoadingImage = false
            }
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
}

