//
//  FriendAlbumView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//

import SwiftUI

struct FriendAlbumView: View {
    let friendName: String
    let friendUUID: String // 友達のUUIDを追加
    @State private var photos: [AlbumPhoto] = [] // クラウドから読み込むため空で初期化
    @State private var selectedImage: AlbumPhoto?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            // 背景
            Color.clear
                .background(
                    Image("CorkBoard_bg") // コルクボードの背景画像
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea(edges: .top)
                )
                .ignoresSafeArea() // 全画面に適用

            VStack(spacing: 0) {
                // 上部タイトルバーエリア
                HStack {
                    Text("\(friendName)'s Album")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.leading, 20)
                    Spacer()
                }
                .frame(height: 80) // タイトルバーの高さ
                .background(Color.white.opacity(0.9)) // 半透明の白背景
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2) // 控えめなシャドウ

                if isLoading {
                    ProgressView("Loading Photos...")
                        .padding()
                } else if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                } else if photos.isEmpty {
                    ContentUnavailableView(
                        "No Photos with \(friendName)",
                        systemImage: "photo.on.rectangle",
                        description: Text("Take photos with \(friendName) to see them here!")
                    )
                    .padding(.top, 50)
                } else {
                    // 横スクロールのアルバム写真表示
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .center, spacing: 24) { // alignmentを.centerに調整
                            ForEach(photos) { photo in
                                // GeometryReader と rotation3DEffect を削除
                                AlbumCardView(
                                    photo: photo,
                                    isDeleteMode: false,
                                    onDelete: {}, // 友達のアルバムからは削除できないため空
                                    onSelect: {
                                        selectedImage = photo
                                    }
                                )
                                .offset(y: CGFloat.random(in: -40...40)) // Yオフセットの範囲を調整
                                .frame(width: 180, height: 220) // AlbumCardViewのフレームと同じにする
                            }
                        }
                        .padding(.horizontal, 20) // 横パディング
                        .padding(.vertical, 40) // 上下のパディングを増やしてカードが中央に来るように
                        .padding(.bottom, 120) // タブバー回避
                    }
                    .frame(maxHeight: .infinity)
                }
                Spacer()
            }
        }
        .sheet(item: $selectedImage) { photo in
            // Assuming AlbumPhotoView is the correct detail view based on your other file
            AlbumPhotoView(
                photo: photo,
                onClose: { selectedImage = nil }
            )
        }
        .onAppear {
            loadFriendPhotos()
        }
        .onChange(of: AuthManager.shared.isAuthenticated) { _ in
            // 認証状態が変更されたら写真を再ロード
            loadFriendPhotos()
        }
    }

    // MARK: - 友達のアルバム写真をロード
    private func loadFriendPhotos() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let fetchedPhotos = try await AlbumManager.shared.loadFriendAlbumPhotos(friendUUID: friendUUID)
                DispatchQueue.main.async {
                    self.photos = fetchedPhotos
                    self.isLoading = false
                    print("[FriendAlbumView] ✅ 友達のアルバム写真ロード完了: \(fetchedPhotos.count)件 for \(friendName)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("[FriendAlbumView] ❌ 友達のアルバム写真ロード失敗: \(error.localizedDescription)")
                }
            }
        }
    }

    // calculateRotation 関数は不要になったため削除
}

