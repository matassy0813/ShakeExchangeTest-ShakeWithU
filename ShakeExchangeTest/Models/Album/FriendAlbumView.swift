//
//  FriendAlbumView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//

// FriendAlbumView.swift を全面的に修正

import SwiftUI
import FirebaseFirestore // DocumentSnapshotのために必要

struct FriendAlbumView: View {
    let friendName: String
    let friendUUID: String
    
    @State private var photos: [AlbumPhoto] = []
    @State private var selectedImage: AlbumPhoto?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    
    // --- ページング用のState変数を追加 ---
    @State private var lastDocumentSnapshot: DocumentSnapshot?
    @State private var isLoadingMore: Bool = false

    var body: some View {
        ZStack {
            // (背景などのUIは変更なし)
            Color.clear
                .background(
                    Image("CorkBoard_bg")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea(edges: .top)
                )
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // (タイトルバーなどのUIは変更なし)
                HStack {
                    Text("\(friendName)'s Album")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.leading, 20)
                    Spacer()
                }
                .frame(height: 80)
                .background(Color.white.opacity(0.9))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)

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
                    ScrollView(.horizontal, showsIndicators: false) {
                        // --- HStackをLazyHStackに変更 ---
                        LazyHStack(alignment: .center, spacing: 24) {
                            ForEach(photos) { photo in
                                AlbumCardView(
                                    photo: photo,
                                    isDeleteMode: false,
                                    onDelete: {},
                                    onSelect: { selectedImage = photo }
                                )
                                .offset(y: CGFloat.random(in: -40...40))
                                .frame(width: 180, height: 220)
                                // --- .onAppearで次のデータを読み込む ---
                                .onAppear {
                                    if photo.id == photos.last?.id && !isLoadingMore {
                                        Task {
                                            await loadMorePhotos()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 40)
                        .padding(.bottom, 120)
                    }
                    .frame(maxHeight: .infinity)
                }
                Spacer()
            }
        }
        .sheet(item: $selectedImage) { photo in
            AlbumPhotoView(photo: photo, onClose: { selectedImage = nil })
        }
        .onAppear {
            if photos.isEmpty { // 最初の1回だけ実行
                Task {
                    await loadInitialPhotos()
                }
            }
        }
        .onChange(of: AuthManager.shared.isAuthenticated) { isAuthenticated in
            if isAuthenticated && photos.isEmpty { // 認証状態が変わり、写真がまだなければ再読み込み
                Task {
                    await loadInitialPhotos()
                }
            }
        }
    }

    // --- 写真読み込みロジックをページング対応に修正 ---

    private func loadInitialPhotos() async {
        isLoading = true
        errorMessage = nil
        do {
            let (fetchedPhotos, lastDoc) = try await AlbumManager.shared.loadFriendAlbumPhotos(friendUUID: friendUUID)
            self.photos = fetchedPhotos
            self.lastDocumentSnapshot = lastDoc
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    private func loadMorePhotos() async {
        // 既に全件読み込んでいる場合は何もしない
        guard let lastDoc = lastDocumentSnapshot else { return }

        isLoadingMore = true
        do {
            let (newPhotos, nextDoc) = try await AlbumManager.shared.loadFriendAlbumPhotos(friendUUID: friendUUID, startAfter: lastDoc)
            self.photos.append(contentsOf: newPhotos)
            self.lastDocumentSnapshot = nextDoc
        } catch {
            // 追加読み込みのエラーは、ユーザーにアラート表示しない場合が多い
            print("❌ 友達アルバムの追加読み込み失敗: \(error.localizedDescription)")
        }
        isLoadingMore = false
    }
}

