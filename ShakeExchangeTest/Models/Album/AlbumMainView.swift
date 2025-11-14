//
//  AlbumMainView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//
import SwiftUI

struct AlbumMainView: View {
    @ObservedObject var friendManager = FriendManager.shared // 友達リストを監視
    @ObservedObject var profileManager = ProfileManager.shared // 自分のプロフィールを監視

    // 自分の最近の写真（AlbumPhotoオブジェクト）
    @State private var myRecentPhotos: [AlbumPhoto] = []
    @State private var isLoadingMyRecentPhotos: Bool = true
    @State private var myRecentPhotosErrorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) { // 全体的なスペーシングを増やす
                    // 自分のアルバムボタン
                    NavigationLink(destination: MyAlbumView()) {
                        HStack {
                            // 自分のアイコン
                            if let uiImage = loadUserIcon(named: profileManager.currentUser.icon) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .frame(width: 50, height: 50) // アイコンを少し大きく
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.purple, lineWidth: 2)) // アクセントカラーの枠
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                    .foregroundColor(.gray)
                            }

                            Text("My Album")
                                .font(.title2) // フォントサイズを大きく
                                .fontWeight(.bold)
                                .padding(.leading, 8)
                            

                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15) // 角を丸く
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.purple.opacity(0.3), Color.black]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .purple.opacity(0.3), radius: 10)
                                .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 3) // 控えめなシャドウ
                        )
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal) // 横パディング

                    // 友達のアルバム一覧
                    VStack(alignment: .leading, spacing: 16) { // スペーシングを調整
                        Text("Friend Albums")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal)

                        if friendManager.friends.isEmpty {
                            ContentUnavailableView(
                                "No Friends Yet",
                                systemImage: "person.3.fill",
                                description: Text("Shake to connect with friends and see their albums here!")
                            )
                            .foregroundColor(.white.opacity(0.7))
                            .frame(height: 150) // 高さ指定
                            .padding(.horizontal)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) { // 横スクロールを追加
                                HStack(spacing: 12) {
                                    ForEach(friendManager.friends) { friend in
                                        NavigationLink(
                                            destination: FriendAlbumView(
                                                friendName: friend.name,
                                                friendUUID: friend.uuid
                                            )
                                        ) {
                                            FriendAlbumCardView(friend: friend)
                                                .frame(width: 160) // カードの幅を固定
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 8) // スクロールインジケータのためのパディング
                            }
                        }
                    }

                    // 最近の写真（自分のアルバムの最新6枚）
                    VStack(alignment: .leading, spacing: 16) { // スペーシングを調整
                        Text("Recent Photos")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal)

                        if isLoadingMyRecentPhotos {
                            ProgressView("Loading recent photos...")
                                .padding()
                                .foregroundColor(.white.opacity(0.7))
                        } else if let error = myRecentPhotosErrorMessage {
                            Text("Error loading recent photos: \(error)")
                                .foregroundColor(.white.opacity(0.7))
                                .padding()
                        } else if myRecentPhotos.isEmpty {
                            ContentUnavailableView(
                                "No Recent Photos",
                                systemImage: "photo.fill.on.rectangle.fill",
                                description: Text("Take photos with your friends to see them here!")
                            )
                            .foregroundColor(.white.opacity(0.7))
                            .frame(height: 150) // 高さ指定
                            .padding(.horizontal)
                        } else {
                            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 10) {
                                ForEach(myRecentPhotos.prefix(6)) { photo in
                                    // Storageから画像をダウンロードして表示
                                    AlbumImageView(storagePath: photo.outerImage)
                                        .frame(width: 110, height: 110) // 画像サイズを少し大きく
                                        .clipped()
                                        .cornerRadius(12) // 角を丸く
                                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2) // シャドウを追加
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical) // 全体の縦パディング
            }
            .navigationTitle("Albums")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.black)
        }
        .onAppear {
            loadMyRecentPhotos()
        }
        .onChange(of: profileManager.currentUser.recentPhotos) { _ in
            // ProfileManagerのrecentPhotosが更新されたら再ロード
            loadMyRecentPhotos()
        }
        .onChange(of: AuthManager.shared.isAuthenticated) { _ in
            // 認証状態が変更されたら写真を再ロード
            loadMyRecentPhotos()
        }
    }
    
    // MARK: - 自分の最近の写真をロード
    private func loadMyRecentPhotos() {
        isLoadingMyRecentPhotos = true
        myRecentPhotosErrorMessage = nil
        Task {
            do {
                let maxPhotosToLoad = 10
                let (fetchedPhotos, _) = try await AlbumManager.shared.loadMyAlbumPhotos(limit: maxPhotosToLoad) 
                DispatchQueue.main.async {
                    // 日付の新しい順にソートして、最新のものを取得
                    self.myRecentPhotos = fetchedPhotos.sorted(by: { $0.date > $1.date })
                    self.isLoadingMyRecentPhotos = false
                    print("[AlbumMainView] ✅ 自分の最近の写真ロード完了: \(self.myRecentPhotos.count)件")
                }
            } catch {
                DispatchQueue.main.async {
                    self.myRecentPhotosErrorMessage = error.localizedDescription
                    self.isLoadingMyRecentPhotos = false
                    print("[AlbumMainView] ❌ 自分の最近の写真ロード失敗: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - アイコン画像読み込みヘルパー (ProfileManagerからコピー)
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
}

// MARK: - AlbumImageView: Storageから画像を読み込むヘルパービュー
struct AlbumImageView: View {
    let storagePath: String
    @State private var image: UIImage? = nil
    @State private var isLoading: Bool = true
    @State private var initialScale: CGFloat = 0.8 // 初回表示時のスケール
    @State private var initialOpacity: Double = 0 // 初回表示時の透明度

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.1)) // 薄い背景色
                    .cornerRadius(12) // 角を丸く
            } else if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo") // 画像がない場合のプレースホルダー
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray.opacity(0.6)) // 控えめな色
                    .padding(20) // パディングを増やす
            }
        }
        .onAppear(perform: loadImage)
        .onChange(of: storagePath) { _ in
            loadImage() // パスが変更されたら画像を再ロード
        }
        .scaleEffect(initialScale) // 初回表示スケール
        .opacity(initialOpacity) // 初回表示透明度
        .onAppear {
            withAnimation(.easeOut(duration: 0.3).delay(Double.random(in: 0...0.1))) { // ランダムな遅延で登場
                initialScale = 1.0
                initialOpacity = 1.0
            }
        }
    }

    private func loadImage() {
        isLoading = true
        image = nil // 古い画像をクリア
        Task {
            // AlbumManager.shared.downloadImage は非同期（バックグラウンド）で実行される
            let loadedImage = await AlbumManager.shared.downloadImage(from: storagePath)
            
            // 【修正】デコード処理が完了した UIImage をメインスレッドで割り当てる
            // （SwiftUIのTask内で実行するため、明示的なDispatchQueue.globalは不要だが、コードの堅牢性のため非同期処理の実行を待つ）
            let processedImage: UIImage? = await withCheckedContinuation { continuation in
                // ダウンロード自体は非同期。デコードはここで暗黙的に発生するが、Task内なのでメインスレッドはブロックしない
                continuation.resume(returning: loadedImage)
            }

            await MainActor.run { // MainActorに切り替えてUIを更新
                self.image = processedImage
                self.isLoading = false
            }
        }
    }
}
