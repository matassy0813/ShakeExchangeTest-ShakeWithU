//
//  CameraPreviewView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/21.
//
import SwiftUI
import GoogleMobileAds // インポートはそのまま

struct CameraPreviewView: View {
    @Binding var mainImage: UIImage
    @Binding var subImage: UIImage
    @Namespace private var imageSwap
    @State var isSwapped: Bool = false

    // InterstitialAdManager のインスタンスを保持
    @StateObject private var interstitialAdManager = InterstitialAdManager()

    // 変更: このビューを閉じるためのpresentationMode
    @Environment(\.presentationMode) var presentationMode
    // 追加: CameraView を閉じるためのBinding
    @Binding var shouldDismissCameraView: Bool

    var receivedUser: CurrentUser // CameraViewから受け取る相手のユーザー情報
    var friendName: String
    var friendIcon: String
    var userIcon: String

    @State private var isSavingPhoto: Bool = false // 写真保存中のインジケーター
    @State private var showingSaveAlert: Bool = false
    @State private var saveAlertMessage: String = ""
    @State private var navigateToConfirmation: Bool = false // 確認ポップアップへの遷移フラグ
    @State private var navigateToPhotoDetail: Bool = false // PhotoDetailViewへの遷移フラグ (今回は未使用だが残しておく)
    @State private var photoToShowInDetail: AlbumPhoto? = nil // PhotoDetailViewに渡す写真 (今回は未使用だが残しておく)
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
            if let photo = self.savedAlbumPhoto {
                PhotoExchangeConfirmationView(
                    savedPhoto: photo,
                    receivedUser: receivedUser,
                    // 修正: onCompletion クロージャが呼ばれたら、CameraPreviewView と CameraView も閉じる
                    onCompletion: { savedPhoto, dismissConfirmation in
                        dismissConfirmation() // PhotoExchangeConfirmationView を閉じる
                        self.presentationMode.wrappedValue.dismiss() // CameraPreviewView を閉じる
                        self.shouldDismissCameraView = true // CameraView を閉じるように通知
                        print("[CameraPreviewView] PhotoExchangeConfirmationViewが閉じられました。CameraPreviewViewとCameraViewを閉じます。")
                    }
                )
            } else {
                Text("エラー: 写真が保存されていません。")
            }
        }
        .fullScreenCover(isPresented: $navigateToPhotoDetail) {
            // PhotoDetailView を表示 (今回は未使用だが残しておく)
            if let photo = self.photoToShowInDetail {
                PhotoDetailView(photo: photo, receivedUser: receivedUser)
            } else {
                Text("エラー: 交換された写真の詳細をロードできませんでした。")
            }
        }
        .onAppear {
            // ビューが表示されたときに広告をプリロードしておく
            interstitialAdManager.loadAd()
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
                    outerImage: mainImage,
                    innerImage: subImage,
                    receivedUser: receivedUser,
                    note: ""
                )
                print("[CameraPreviewView] ✅ 写真のクラウド保存とメタデータ登録が完了しました。")
                
                // 保存成功後
                DispatchQueue.main.async {
                    self.isSavingPhoto = false
                    self.savedAlbumPhoto = savedPhoto // 保存した写真を保持

                    // 修正: rootViewController を取得し、広告表示に渡す
                    if let rootViewController = UIApplication.shared.topMostViewController {
                        interstitialAdManager.showAd(
                            from: rootViewController, // 引数を修正
                            onPresented: {
                                // 広告が表示された瞬間に行う処理（今回は画面を閉じない）
                                print("[CameraPreviewView] ℹ️ 広告表示完了。")
                            },
                            onDismissed: {
                                // 広告が閉じられた、または表示されなかった場合に実行される
                                self.navigateToConfirmation = true
                                print("[CameraPreviewView] ✅ 広告閉鎖（またはスキップ）、PhotoExchangeConfirmationView を開きます。")
                            }
                        )
                    } else {
                        print("❗️ topMostViewController の取得に失敗しました。広告なしで画面遷移します。")
                        self.navigateToConfirmation = true
                    }
                }

            } catch let error as NSError {
                print("[CameraPreviewView] ❌ 写真保存失敗: \(error.localizedDescription) (Code: \(error.code))")
                DispatchQueue.main.async {
                    self.isSavingPhoto = false
                    if error.domain == "FIRStorageErrorDomain" {
                        self.saveAlertMessage = "写真のアップロードに失敗しました (コード: \(error.code))。\n\nネットワーク接続をご確認いただくか、アプリのカメラ・写真アクセス権限が許可されているかご確認ください。"
                    } else if error.domain == "FIRFirestoreErrorDomain" {
                        self.saveAlertMessage = "写真情報の保存に失敗しました (コード: \(error.code))。\n\nネットワーク接続をご確認いただくか、Firebaseのデータベース設定をご確認ください。"
                    } else {
                        self.saveAlertMessage = "写真の保存に失敗しました: \(error.localizedDescription)"
                    }
                    self.showingSaveAlert = true
                }
            } catch {
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
        if let image = UIImage(named: filename) {
            return image
        }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
}

// 拡張はそのまま残します
extension UIApplication {
    var topMostViewController: UIViewController? {
        connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .filter { $0.isKeyWindow }
            .first?
            .rootViewController?
            .topMostViewController
    }
}

extension UIViewController {
    var topMostViewController: UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController
        }
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topMostViewController ?? navigation
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController ?? tab
        }
        return self
    }
}
