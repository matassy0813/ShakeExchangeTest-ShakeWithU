//
//  AlbumCardView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/23.
//
import SwiftUI

struct AlbumCardView: View {
    let photo: AlbumPhoto
    var isDeleteMode: Bool
    var onDelete: () -> Void
    var onSelect: () -> Void

    @State private var isSwapped: Bool = false
    @State private var outerImage: UIImage? = nil
    @State private var innerImage: UIImage? = nil
    @State private var isLoadingImages: Bool = true
    @State private var jiggleAmount: Double = 0 // 揺れのアニメーション用
    @State private var initialScale: CGFloat = 0.8 // 初回表示時のスケール
    @State private var initialOpacity: Double = 0 // 初回表示時の透明度
    @GestureState private var isPressing: Bool = false // タップ中の状態

    // タイマーの参照を保持するためのプロパティ
    @State private var timer: Timer?

    // ランダムなフレームスタイルを定義
    private let frameStyles: [AnyView] = [
        AnyView(Rectangle().stroke(Color.white, lineWidth: 5).shadow(radius: 3)),
        AnyView(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.8), lineWidth: 3).shadow(radius: 2)),
        // TODO: アセットカタログに "tape_corner_top_left" と "tape_corner_top_right" を追加してください。
        // これらはマスキングテープの画像など、スクラップブック感を出すためのものです。
        // もし画像がない場合は、シンプルな白い四角や角丸四角のフレームを使用してください。
        AnyView(
            Image("tape_corner_top_left") // Make sure this asset exists or provide a fallback
                .resizable()
                .frame(width: 30, height: 30)
                .offset(x: -15, y: -15)
                .shadow(radius: 1)
        ),
        AnyView(
            Image("tape_corner_top_right") // Make sure this asset exists or provide a fallback
                .resizable()
                .frame(width: 30, height: 30)
                .offset(x: 15, y: -15)
                .shadow(radius: 1)
        )
    ]
    @State private var selectedFrameStyle: Int = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // カードの背景とシャドウ
            RoundedRectangle(cornerRadius: 16) // 角をさらに丸く
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.9), Color.black]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 180, height: 220)
                .shadow(color: .white.opacity(0.08), radius: 10, x: 0, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )

            VStack(spacing: 0) { // スペーシングを調整
                // ピンのデザイン
                Circle()
                    .fill(photo.pinColor)
                    .frame(width: 16, height: 16) // ピンを少し大きく
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    .shadow(radius: 2)
                    .offset(y: -8) // 上に少しずらす

                // 画像表示エリア
                ZStack(alignment: .topTrailing) {
                    if isLoadingImages {
                        ProgressView() // 画像読み込み中のインジケーター
                            .frame(width: 160, height: 150) // 画像エリアを調整
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12) // 画像の角も丸く
                    } else {
                        // メイン画像 (Storageからダウンロード)
                        Image(uiImage: isSwapped ? (innerImage ?? UIImage()) : (outerImage ?? UIImage()))
                            .resizable()
                            .aspectRatio(contentMode: .fill) // 縦横比を維持しつつ、フレームを埋める
                            .frame(width: 160, height: 150)
                            .clipped() // フレームからはみ出た部分をクリップ
                            .cornerRadius(12) // 画像の角を丸く
                            .overlay(frameStyles[selectedFrameStyle]) // ランダムフレームを適用

                        // サブ画像 (Storageからダウンロード)
                        Image(uiImage: isSwapped ? (outerImage ?? UIImage()) : (innerImage ?? UIImage()))
                            .resizable()
                            .aspectRatio(contentMode: .fill) // こちらもfillに
                            .frame(width: 55, height: 55) // サブ画像を少し大きく
                            .clipShape(RoundedRectangle(cornerRadius: 10)) // 角を丸く
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.8), lineWidth: 2) // 白いボーダーで強調
                            )
                            .shadow(radius: 3)
                            .padding(8) // パディングを調整
                            .onTapGesture {
                                withAnimation(.spring()) { // スプリングアニメーションで滑らかに
                                    isSwapped.toggle()
                                }
                            }
                    }
                }
                .padding(.bottom, 8) // 画像とテキストの間のスペース

                // 日付とメモの表示
                VStack(spacing: 4) {
                    Text(photo.date)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)

                    if !photo.note.isEmpty {
                        Text(photo.note)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.horizontal, 8)
                    }
                }
                .frame(maxWidth: .infinity) // 幅いっぱいに広げる
                .padding(.bottom, 12) // 下部のパディング
            }
            .padding(.top, 16) // 全体の上部パディング

            // 削除ボタン (右上に配置)
            if isDeleteMode {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2) // アイコンを大きく
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.black.opacity(0.8)))
                        .clipShape(Circle())
                        .shadow(radius: 2)
                        .padding(4)
                }
                .offset(x: 8, y: -8) // 右上に少しはみ出すように配置
                .transition(.scale) // 削除モード切り替え時にスケールアニメーション
            }
        }
        .rotationEffect(.degrees(photo.rotation + jiggleAmount)) // 揺れを追加
        .scaleEffect(isPressing ? 1.05 : initialScale) // タップ中の拡大と初回表示スケール
        .opacity(initialOpacity) // 初回表示透明度
        .animation(.easeOut(duration: 0.1), value: isPressing) // タップアニメーション
        .onTapGesture {
            if !isDeleteMode {
                onSelect()
            }
        }
        .onAppear {
            loadImagesFromStorage()
            startJiggleAnimation() // 揺れアニメーションを開始
            withAnimation(.easeOut(duration: 0.3).delay(Double.random(in: 0...0.1))) { // ランダムな遅延で登場
                initialScale = 1.0
                initialOpacity = 1.0
            }
            selectedFrameStyle = Int.random(in: 0..<frameStyles.count) // ランダムなフレームスタイルを選択
        }
        .onDisappear {
            stopJiggleAnimation() // 揺れアニメーションを停止
        }
        .gesture(
            LongPressGesture(minimumDuration: 0.1) // 短いタップでも反応
                .updating($isPressing) { currentState, gestureState, transaction in
                    gestureState = currentState
                }
        )
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
    
    // MARK: - 揺れアニメーション
    private func startJiggleAnimation() {
        // 既存のタイマーがあれば停止
        timer?.invalidate()
        // わずかなランダムな揺れを継続的に適用
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                jiggleAmount = Double.random(in: -0.2...0.2) // わずかな揺れに調整
            }
        }
    }
    
    private func stopJiggleAnimation() {
        timer?.invalidate()
        timer = nil
    }
}
