//
//  MyAlbumView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//
import SwiftUI

enum AlbumSortOption: String, CaseIterable {
    case newest = "Newest"
    case oldest = "Oldest"
    case random = "Random"
}

struct MyAlbumView: View {
    @State private var photos: [AlbumPhoto] = [] // クラウドから読み込むため空で初期化
    @State private var selectedImage: AlbumPhoto? = nil
    @State private var isDeleteMode: Bool = false
    @State private var sortOption: AlbumSortOption = .newest
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil

    var sortedPhotos: [AlbumPhoto] {
        switch sortOption {
        case .newest: return photos.sorted(by: { $0.date > $1.date }) // 日付でソート
        case .oldest: return photos.sorted(by: { $0.date < $1.date }) // 日付でソート
        case .random: return photos.shuffled()
        }
    }

    var body: some View {
        ZStack {
            // 🔳 背景は常に画面全体に広がる
            Color.clear
                .background(
                    // "CorkBoard_bg" はアセットカタログに含めるか、ローカルパスで読み込む
                    Image("CorkBoard_bg") // コルクボードの背景画像
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea(edges: .top)
                )
                .ignoresSafeArea() // 全画面に適用

            VStack(spacing: 0) {
                // 上部タイトルバーエリア
                HStack {
                    Text("My Album")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.leading, 20)
                    
                    Spacer()

                    // ソートオプション
                    Picker("Sort", selection: $sortOption) {
                        ForEach(AlbumSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.trailing, 10)
                    .tint(.purple) // ピッカーのテキスト色

                    // 削除モード切り替えボタン
                    Button(action: {
                        withAnimation { // 削除モード切り替えにアニメーションを追加
                            isDeleteMode.toggle()
                        }
                    }) {
                        Image(systemName: isDeleteMode ? "trash.fill" : "trash")
                            .font(.title2)
                            .foregroundColor(isDeleteMode ? .red : .gray)
                    }
                    .padding(.trailing, 20)
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
                        "No Photos Yet",
                        systemImage: "photo.on.rectangle",
                        description: Text("Take photos with your friends to add them to your album!")
                    )
                    .padding(.top, 50)
                } else {
                    // 🧾 アルバム一覧（横スクロール）
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .center, spacing: 24) { // alignmentを.centerに調整
                            ForEach(sortedPhotos) { photo in
                                // GeometryReader と rotation3DEffect を削除
                                AlbumCardView(
                                    photo: photo,
                                    isDeleteMode: isDeleteMode,
                                    onDelete: {
                                        // TODO: Firebaseからの削除ロジックを実装
                                        print("写真削除リクエスト: \(photo.id)")
                                        // 削除後、photos配列を更新してUIを再描画
                                        // Example: photos.removeAll(where: { $0.id == photo.id })
                                    },
                                    onSelect: {
                                        selectedImage = photo
                                    }
                                )
                                // Yオフセットは残す (ランダムな配置は維持)
                                .offset(y: CGFloat.random(in: -40...40)) // Yオフセットの範囲を調整
                                .frame(width: 180, height: 220) // AlbumCardViewのフレームと同じにする
                            }
                        }
                        .padding(.horizontal, 20) // 横パディング
                        .padding(.vertical, 40) // 上下のパディングを増やしてカードが中央に来るように
                        .padding(.bottom, 120) // タブバー回避のためのパディング
                    }
                    .frame(maxHeight: .infinity)
                }
                Spacer() // ⬅️ 下にも空間を
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
            loadMyPhotos()
        }
        .onChange(of: AuthManager.shared.isAuthenticated) { _ in
            // 認証状態が変更されたら写真を再ロード
            loadMyPhotos()
        }
    }

    // MARK: - 自分のアルバム写真をロード
    private func loadMyPhotos() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let (fetchedPhotos, _) = try await AlbumManager.shared.loadMyAlbumPhotos(limit: 30)
                DispatchQueue.main.async {
                    self.photos = fetchedPhotos
                    self.isLoading = false
                    print("[MyAlbumView] ✅ 自分のアルバム写真ロード完了: \(fetchedPhotos.count)件")
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("[MyAlbumView] ❌ 自分のアルバム写真ロード失敗: \(error.localizedDescription)")
                }
            }
        }
    }

    // calculateRotation 関数は不要になったため削除
}

