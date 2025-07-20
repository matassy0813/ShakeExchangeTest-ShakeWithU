//
//  AlbumPhotoDetailView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/07.
//

import SwiftUI

struct PhotoDetailView: View { // PhotoDetailViewという名前はAlbumPhotoDetailViewの方が適切かもしれません
    var photo: AlbumPhoto
    var receivedUser: CurrentUser // 相手のユーザー情報
    @Environment(\.presentationMode) var presentationMode

    @State private var outerImage: UIImage? = nil
    @State private var innerImage: UIImage? = nil // innerImageをvarに変更
    @State private var isLoadingImages: Bool = true
    @State private var isSwapped: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea() // 背景は黒でフルスクリーン

            VStack(spacing: 20) {
                // ヘッダー (相手の名前とアイコン)
                HStack {
                    if let uiImage = loadImage(named: receivedUser.icon) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .clipShape(Circle())
                            .frame(width: 48, height: 48) // アイコンを少し大きく
                            .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1)) // 白い枠
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .clipShape(Circle())
                            .frame(width: 48, height: 48)
                            .foregroundColor(.gray)
                    }
                    Text(receivedUser.name)
                        .font(.title2) // フォントを大きく
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.2))) // 背景を追加
                    .cornerRadius(20)
                }
                .padding(.horizontal)
                .padding(.top, 10) // 上部パディング

                // 写真表示エリア
                ZStack(alignment: .topTrailing) {
                    if isLoadingImages {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: 450) // サイズを調整
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(20) // 角を丸く
                            .padding(.horizontal)
                    } else {
                        Image(uiImage: isSwapped ? (innerImage ?? UIImage()) : (outerImage ?? UIImage()))
                            .resizable()
                            .scaledToFit() // アスペクト比を維持してフィット
                            .cornerRadius(20) // 角を丸く
                            .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8) // 影を強調
                            .padding(.horizontal)
                            .onTapGesture {
                                withAnimation(.spring()) { // スプリングアニメーション
                                    isSwapped.toggle()
                                }
                            }

                        // サub画像 (右上に小さく表示)
                        Image(uiImage: isSwapped ? (outerImage ?? UIImage()) : (innerImage ?? UIImage()))
                            .resizable()
                            .scaledToFill() // Fillに変更
                            .frame(width: 120, height: 120) // サイズを調整
                            .clipShape(RoundedRectangle(cornerRadius: 18)) // 角を丸く
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.white.opacity(0.8), lineWidth: 3) // 白いボーダーで強調
                            )
                            .shadow(radius: 8)
                            .padding(20) // パディングを調整
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    isSwapped.toggle()
                                }
                            }
                    }
                }

                // 写真情報
                VStack(alignment: .leading, spacing: 10) { // スペーシングを調整
                    Text("Date: \(photo.date)")
                        .font(.title3) // フォントサイズを大きく
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    if !photo.note.isEmpty {
                        Text("Note: \(photo.note)")
                            .font(.body) // フォントサイズを調整
                            .foregroundColor(.white.opacity(0.8)) // 控えめな白
                            .multilineTextAlignment(.leading) // 左揃え
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                Spacer()
            }
        }
        .onAppear {
            loadImagesFromStorage()
        }
    }

    // MARK: - Firebase Storageから画像をダウンロード
    private func loadImagesFromStorage() {
        isLoadingImages = true
        Task {
            async let loadedOuter = AlbumManager.shared.downloadImage(from: photo.outerImage)
            async let loadedInner = AlbumManager.shared.downloadImage(from: photo.innerImage)

            let (outer, inner) = await (loadedOuter, loadedInner)

            DispatchQueue.main.async {
                self.outerImage = outer
                self.innerImage = inner
                self.isLoadingImages = false
            }
        }
    }

    // MARK: - アイコン画像読み込みヘルパー
    private func loadImage(named filename: String) -> UIImage? {
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
