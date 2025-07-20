//
//  AlbumPhotoView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/23.
//

import SwiftUI

struct AlbumPhotoView: View {
    var photo: AlbumPhoto
    var onClose: () -> Void

    @State private var isSwapped: Bool = false
    @State private var outerImage: UIImage? = nil
    @State private var innerImage: UIImage? = nil
    @State private var isLoadingImages: Bool = true // 画像読み込み中フラグ

    var body: some View {
        ZStack {
            // 背景を暗くし、半透明にする
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()

                // 写真表示エリア
                ZStack(alignment: .topTrailing) {
                    if isLoadingImages {
                        ProgressView() // 画像読み込み中のインジケーター
                            .frame(maxWidth: .infinity, maxHeight: 350) // サイズを調整
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(20) // 角を丸く
                            .padding()
                    } else {
                        // メイン画像表示 (outerImage または innerImage)
                        if let displayImage = isSwapped ? innerImage : outerImage {
                            Image(uiImage: displayImage)
                                .resizable()
                                .scaledToFit() // アスペクト比を維持してフィット
                                .cornerRadius(20) // 角を丸く
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5) // 影を追加
                                .padding()
                                .onTapGesture {
                                    withAnimation(.spring()) { // スプリングアニメーション
                                        isSwapped.toggle()
                                    }
                                }
                        } else {
                            // 画像が読み込めなかった場合のプレースホルダー
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 350)
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(50) // アイコンのパディング
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(20)
                                .padding()
                        }

                        // サブ画像 (右上に小さく表示)
                        // メイン画像が読み込まれている場合のみサブ画像も表示
                        if let subImage = isSwapped ? outerImage : innerImage, !isLoadingImages {
                            Image(uiImage: subImage)
                                .resizable()
                                .scaledToFill() // Fillに変更
                                .frame(width: 90, height: 90) // サイズを調整
                                .clipShape(RoundedRectangle(cornerRadius: 16)) // 角を丸く
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.8), lineWidth: 2) // 白いボーダーで強調
                                )
                                .shadow(radius: 5)
                                .padding(16) // パディングを調整
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        isSwapped.toggle()
                                    }
                                }
                        }
                    }
                }

                // 写真情報
                VStack(spacing: 8) { // スペーシングを調整
                    Text(photo.date)
                        .font(.title2) // フォントサイズを大きく
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    if !photo.note.isEmpty {
                        Text(photo.note)
                            .font(.body) // フォントサイズを調整
                            .foregroundColor(.white.opacity(0.8)) // 控えめな白
                            .multilineTextAlignment(.center) // 中央揃え
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // 閉じるボタン
                Button(action: onClose) {
                    Text("Close")
                        .fontWeight(.semibold)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(16) // 角を丸く
                        .shadow(radius: 5)
                        .padding(.horizontal, 20) // 横パディング
                }
                .padding(.bottom, 20) // 下部パディング
            }
        }
        .onAppear {
            loadImagesFromStorage()
        }
    }

    // MARK: - Firebase Storageから画像をダウンロード
    private func loadImagesFromStorage() {
        isLoadingImages = true
        outerImage = nil // 古い画像をクリア
        innerImage = nil
        print("[AlbumPhotoView] 🔄 画像読み込み開始: OuterPath='\(photo.outerImage)', InnerPath='\(photo.innerImage)'")

        Task {
            async let loadedOuter = AlbumManager.shared.downloadImage(from: photo.outerImage)
            async let loadedInner = AlbumManager.shared.downloadImage(from: photo.innerImage)

            let (outer, inner) = await (loadedOuter, loadedInner)

            DispatchQueue.main.async {
                self.outerImage = outer
                self.innerImage = inner
                self.isLoadingImages = false
                print("[AlbumPhotoView] ✅ 画像読み込み完了: Outer=\(outer != nil), Inner=\(inner != nil)")
                if outer == nil || inner == nil {
                    print("[AlbumPhotoView] ⚠️ 一部または全ての画像が読み込めませんでした。")
                }
            }
        }
    }
}
