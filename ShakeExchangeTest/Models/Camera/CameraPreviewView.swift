//
//  CameraPreviewView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/21.
//
import SwiftUI
import GoogleMobileAds

struct CameraPreviewView: View {
    @Binding var mainImage: UIImage
    @Binding var subImage: UIImage
    @Namespace private var imageSwap
    @State var isSwapped: Bool = false
    @State private var interstitial: InterstitialAd?

    @Environment(\.presentationMode) var presentationMode // ビューを閉じるために使用

    var receivedUser: CurrentUser // CameraViewから受け取る相手のユーザー情報
    var friendName: String
    var friendIcon: String
    var userIcon: String

    @State private var isSavingPhoto: Bool = false // 写真保存中のインジケーター
    @State private var showingSaveAlert: Bool = false
    @State private var saveAlertMessage: String = ""
    @State private var navigateToConfirmation: Bool = false // 確認ポップアップへの遷移フラグ
    @State private var navigateToPhotoDetail: Bool = false // PhotoDetailViewへの遷移フラグ
    @State private var photoToShowInDetail: AlbumPhoto? = nil // PhotoDetailViewに渡す写真
    @State private var savedAlbumPhoto: AlbumPhoto? = nil // 保存されたAlbumPhotoを保持

    var body: some View {
        VStack(spacing: 20) {
            Text("Send Photo")
                .font(.title)
                .bold()

            // プレビューエリア（タップで入れ替え）
            ZStack(alignment: .topTrailing) {
                Group {
                    Image(uiImage: mainImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(12)
                        .matchedGeometryEffect(id: "mainImage", in: imageSwap)
                }
                .onTapGesture {
                    swapImages()
                }

                Group {
                    Image(uiImage: subImage)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(8)
                        .matchedGeometryEffect(id: "subImage", in: imageSwap)
                }
                .onTapGesture {
                    swapImages()
                }
               .onAppear {
                   // Debugging image sizes
                   print("[CameraPreviewView] 🟢 mainImage size: \(mainImage.size)")
                   print("[CameraPreviewView] 🟢 subImage size: \(subImage.size)")
               }

            }
            .animation(.easeInOut(duration: 0.4), value: mainImage)

            // ボタン：戻る / Send
            HStack(spacing: 16) {
                Button("戻る") { // ボタン名を「戻る」に変更
                    presentationMode.wrappedValue.dismiss() // カメラビューに戻る
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.gray)
                .cornerRadius(10)

                Button(action: {
                    savePhotoToCloud()
                }) {
                    if isSavingPhoto {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Send")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isSavingPhoto) // 保存中はボタンを無効化
            }
            .padding(.horizontal)

            // 相手表示
            HStack {
                if let uiImage = loadImage(named: userIcon) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .clipShape(Circle())
                        .frame(width: 60, height: 60)
                } else {
                    Image(userIcon)
                        .resizable()
                        .clipShape(Circle())
                        .frame(width: 60, height: 60)
                }

                Image(systemName: "arrow.right")
                    .foregroundColor(.gray)

                if let uiImage = loadImage(named: friendIcon) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .clipShape(Circle())
                        .frame(width: 60, height: 60)
                } else {
                    Image(friendIcon)
                        .resizable()
                        .clipShape(Circle())
                        .frame(width: 60, height: 60)
                }

                Text(friendName)
                    .font(.subheadline)
            }

            Spacer()
        }
        .padding()
        .alert(isPresented: $showingSaveAlert) { // 保存失敗時のアラート
            Alert(title: Text("エラー"), message: Text(saveAlertMessage), dismissButton: .default(Text("OK")))
        }
        .fullScreenCover(isPresented: $navigateToConfirmation) {
            // ポップアップアニメーションと写真ダウンロード画面
            if let photo = self.savedAlbumPhoto { // <-- self. を追加して明示的に参照
                PhotoExchangeConfirmationView(
                    savedPhoto: photo, // 安全にアンラップされたphotoを渡す
                    receivedUser: receivedUser,
                    onCompletion: { savedPhoto, dismissConfirmation in
                        // PhotoExchangeConfirmationViewが閉じられたら、このビューも閉じる
                        dismissConfirmation() // PhotoExchangeConfirmationViewを閉じる
                        // ここではCameraPreviewViewを閉じない。親ビューからの指示を待つ
                        // presentationMode.wrappedValue.dismiss() // この行を削除またはコメントアウト
                        print("[CameraPreviewView] PhotoExchangeConfirmationViewが閉じられました。")
                    }
                )
            } else {
                Text("エラー: 写真が保存されていません。")
            }
        }
        .fullScreenCover(isPresented: $navigateToPhotoDetail) {
            // PhotoDetailView を表示
            if let photo = self.photoToShowInDetail { // <-- self. を追加して明示的に参照
                PhotoDetailView(photo: photo, receivedUser: receivedUser)
            } else {
                Text("エラー: 交換された写真の詳細をロードできませんでした。")
            }
        }
    }

    private func swapImages() {
        withAnimation {
            let temp = mainImage
            mainImage = subImage
            subImage = temp
        }
    }
    
    // MARK: - 写真をクラウドに保存するロジック
    private func savePhotoToCloud() {
        isSavingPhoto = true
        Task {
            do {
                // AlbumManagerを呼び出して写真を保存・アップロード
                let savedPhoto = try await AlbumManager.shared.saveAndUploadPhoto(
                    outerImage: mainImage, // 直接 mainImage を使用
                    innerImage: subImage,  // 直接 subImage を使用
                    receivedUser: receivedUser,
                    note: "" // 必要であればメモを追加
                )
                print("[CameraPreviewView] ✅ 写真のクラウド保存とメタデータ登録が完了しました。")
                
                // 保存成功後、ポップアップアニメーション画面に遷移
                DispatchQueue.main.async {
                    self.isSavingPhoto = false
                    self.savedAlbumPhoto = savedPhoto // <-- self. を追加して明示的に参照
                    // ✅ 広告表示 → 終了後に画面遷移
                    self.showInterstitialAd {
                        self.navigateToConfirmation = true
                    }
                }

            } catch let error as NSError { // NSErrorとしてキャッチし、より詳細な情報を取得
                print("[CameraPreviewView] ❌ 写真保存失敗: \(error.localizedDescription) (Code: \(error.code))")
                DispatchQueue.main.async {
                    self.isSavingPhoto = false
                    // Firebase StorageやFirestoreのエラーコードを具体的に表示
                    if error.domain == "FIRStorageErrorDomain" {
                        self.saveAlertMessage = "写真のアップロードに失敗しました (コード: \(error.code))。\n\nネットワーク接続をご確認いただくか、アプリのカメラ・写真アクセス権限が許可されているかご確認ください。"
                    } else if error.domain == "FIRFirestoreErrorDomain" {
                        self.saveAlertMessage = "写真情報の保存に失敗しました (コード: \(error.code))。\n\nネットワーク接続をご確認いただくか、Firebaseのデータベース設定をご確認ください。"
                    } else {
                        self.saveAlertMessage = "写真の保存に失敗しました: \(error.localizedDescription)"
                    }
                    self.showingSaveAlert = true
                }
            } catch { // その他のエラー
                print("[CameraPreviewView] ❌ 写真保存失敗: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isSavingPhoto = false
                    self.saveAlertMessage = "写真の保存に失敗しました: \(error.localizedDescription)"
                    self.showingSaveAlert = true
                }
            }
        }
    }

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
    
    func showInterstitialAd(onComplete: @escaping () -> Void) {
        let request = Request()
        InterstitialAd.load(withAdUnitID: "ca-app-pub-6432164084077876~1939978994", request: request) { ad, error in
            if let error = error {
                print("広告のロード失敗: \(error.localizedDescription)")
                onComplete()
                return
            }

            interstitial = ad
            interstitial?.fullScreenContentDelegate = AdDelegate(onDismiss: onComplete)

            if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                interstitial?.present(fromRootViewController: rootVC)
            } else {
                print("❗️rootViewController取得失敗")
                onComplete()
            }
        }
    }
}

class AdDelegate: NSObject, FullScreenContentDelegate {
    let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        onDismiss()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("広告表示失敗: \(error)")
        onDismiss()
    }
}
