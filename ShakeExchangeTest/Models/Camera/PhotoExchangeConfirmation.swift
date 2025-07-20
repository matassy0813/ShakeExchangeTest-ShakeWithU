//
//  PhotoExchangeConfirmation.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/07.
//

import SwiftUI

struct PhotoExchangeConfirmationView: View {
    var savedPhoto: AlbumPhoto // 自分が保存した写真のメタデータ
    var receivedUser: CurrentUser // 相手のユーザー情報
    // 完了時に呼び出すクロージャ。ダウンロードされた写真と、このビューを閉じるアクションを渡す
    // このクロージャは、PhotoExchangeConfirmationViewを閉じるだけでなく、その親ビューも閉じるためのアクションをトリガーする
    var onCompletion: (AlbumPhoto, () -> Void) -> Void

    @State private var showCheckmark: Bool = false
    @State private var showPhotoConfirmation: Bool = false // 写真表示と確認メッセージのための新しい状態
    
    // 表示用の実際のUIImageを保持する状態
    @State private var mainDisplayImage: UIImage? = nil // 自分の写真

    // エラーメッセージの状態とアラート表示の状態
    @State private var errorMessage: String? = nil {
        didSet {
            // errorMessageがnilでなければアラートを表示
            showingErrorAlert = errorMessage != nil
        }
    }
    @State private var showingErrorAlert: Bool = false // エラーアラート表示用フラグ

    @Environment(\.presentationMode) var presentationMode // このビューを閉じるため

    var body: some View {
        ZStack {
            // 強化された背景
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 30) { // スペーシングを増加
                if mainDisplayImage == nil {
                    // 写真がロードされるまでのローディング表示
                    ProgressView("写真を準備中...")
                        .font(.title2)
                        .foregroundColor(.white)
                        .scaleEffect(1.5)
                } else if !showPhotoConfirmation {
                    // 写真がロードされたら、拡大アニメーション
                    Image(uiImage: mainDisplayImage!)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(20)
                        .shadow(radius: 15)
                        .padding(30)
                        .transition(.scale(0.5).combined(with: .opacity)) // 拡大アニメーション
                        .animation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0), value: mainDisplayImage)
                        .onAppear {
                            // 写真が完全に表示されたら、確認メッセージを表示する状態に移行
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    showPhotoConfirmation = true
                                }
                            }
                        }
                } else {
                    // 写真と確認メッセージの表示
                    VStack(spacing: 20) {
                        Image(uiImage: mainDisplayImage!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 250, height: 250) // 少し小さく表示
                            .cornerRadius(20)
                            .shadow(radius: 15)
                            .transition(.opacity) // フェードイン
                            .animation(.easeInOut(duration: 0.5), value: showPhotoConfirmation)

                        if showCheckmark {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80) // アイコンサイズ調整
                                .foregroundColor(.green)
                                .transition(.scale.combined(with: .opacity))
                                .animation(.spring(response: 0.7, dampingFraction: 0.5, blendDuration: 0), value: showCheckmark)
                        }

                        Text("写真を正常に送信しました！")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(radius: 5)
                            .transition(.opacity) // フェードイン
                            .animation(.easeInOut(duration: 0.5).delay(0.2), value: showPhotoConfirmation)

                        Text("\(receivedUser.name)さんとの瞬間を保存しました。")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .transition(.opacity) // フェードイン
                            .animation(.easeInOut(duration: 0.5).delay(0.4), value: showPhotoConfirmation)

                        Button("Done") { // ボタン名を「Done」に変更
                            // 完了時に親ビューのonCompletionを呼び出し、ビュー階層全体を閉じる
                            onCompletion(savedPhoto) { // savedPhotoをそのまま渡す
                                // このdismissはPhotoExchangeConfirmationView自身を閉じる
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 15)
                        .background(Capsule().fill(Color.green))
                        .foregroundColor(.white)
                        .font(.headline)
                        .shadow(radius: 5)
                        .transition(.scale.combined(with: .opacity)) // ボタンの出現アニメーション
                        .animation(.spring(response: 0.7, dampingFraction: 0.5, blendDuration: 0).delay(0.6), value: showPhotoConfirmation)
                    }
                }
            }
            .onAppear(perform: startConfirmationProcess)
            .alert(isPresented: $showingErrorAlert, content: { // エラーアラートをshowingErrorAlertにバインド
                Alert(title: Text("エラー"), message: Text(errorMessage ?? "不明なエラーが発生しました。"), dismissButton: .default(Text("OK")) {
                    self.errorMessage = nil // アラートが閉じられたらエラーメッセージをクリア
                    presentationMode.wrappedValue.dismiss() // ビューを閉じる
                })
            })
        }
    }

    private func startConfirmationProcess() {
        // 自分の写真をロードし、表示
        Task {
            await loadMyPhotosForDisplay()
        }

        // チェックマークのアニメーション開始
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { // 写真ロード後の遅延
            withAnimation {
                showCheckmark = true
            }
        }
    }
    
    // MARK: - 自分の写真をロードし、表示する
    private func loadMyPhotosForDisplay() async {
        // savedPhotoメタデータからメイン画像（outerImage）を読み込む
        let outerImage = await AlbumManager.shared.downloadImage(from: savedPhoto.outerImage)
        if let outerImage = outerImage {
            DispatchQueue.main.async {
                self.mainDisplayImage = outerImage
                print("[PhotoExchangeConfirmationView] ✅ 自分のメイン写真表示完了。")
            }
        } else {
            DispatchQueue.main.async {
                self.errorMessage = "自分の写真のロードに失敗しました。" // エラーメッセージを設定
                print("[PhotoExchangeConfirmationView] ❌ 自分のメイン写真のロードに失敗。")
            }
        }
    }
    
    // ユーザーアイコンを読み込むヘルパー関数 (今回は使用しないが残しておく)
    func loadImage(named filename: String) -> UIImage? {
        // アセットカタログからの読み込みを試行
        if let image = UIImage(named: filename) {
            return image
        }
        // ドキュメントディレクトリからの読み込みを試行
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
}
