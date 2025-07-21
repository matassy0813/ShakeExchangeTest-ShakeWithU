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

    @StateObject private var interstitialAdManager = InterstitialAdManager()

    @Environment(\.presentationMode) var presentationMode
    @Binding var shouldDismissCameraView: Bool

    var receivedUser: CurrentUser
    var friendName: String
    var friendIcon: String
    var userIcon: String

    @State private var isSavingPhoto: Bool = false
    @State private var showingSaveAlert: Bool = false
    @State private var saveAlertMessage: String = ""
    @State private var navigateToConfirmation: Bool = false
    @State private var navigateToPhotoDetail: Bool = false
    @State private var photoToShowInDetail: AlbumPhoto? = nil
    @State private var savedAlbumPhoto: AlbumPhoto? = nil

    var body: some View {
        VStack(spacing: 20) {
            Text("Send Photo")
                .font(.title)
                .bold()

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
                   print("[CameraPreviewView] 🟢 mainImage size: \(mainImage.size)")
                   print("[CameraPreviewView] 🟢 subImage size: \(subImage.size)")
               }

            }
            .animation(.easeInOut(duration: 0.4), value: mainImage)

            HStack(spacing: 16) {
                Button("戻る") {
                    presentationMode.wrappedValue.dismiss()
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
                .disabled(isSavingPhoto)
            }
            .padding(.horizontal)

            // 相手表示
            HStack {
                // MARK: - 堅牢性向上: ユーザーアイコンの表示ロジックを強化
                Image(uiImage: loadImageSafely(named: userIcon))
                    .resizable()
                    .clipShape(Circle())
                    .frame(width: 60, height: 60)

                Image(systemName: "arrow.right")
                    .foregroundColor(.gray)

                // MARK: - 堅牢性向上: フレンドアイコンの表示ロジックを強化
                Image(uiImage: loadImageSafely(named: friendIcon))
                    .resizable()
                    .clipShape(Circle())
                    .frame(width: 60, height: 60)

                Text(friendName)
                    .font(.subheadline)
            }

            Spacer()
        }
        .padding()
        .alert(isPresented: $showingSaveAlert) {
            Alert(title: Text("エラー"), message: Text(saveAlertMessage), dismissButton: .default(Text("OK")))
        }
        .fullScreenCover(isPresented: $navigateToConfirmation) {
            if let photo = self.savedAlbumPhoto {
                PhotoExchangeConfirmationView(
                    savedPhoto: photo,
                    receivedUser: receivedUser,
                    onCompletion: { savedPhoto, dismissConfirmation in
                        dismissConfirmation()
                        self.presentationMode.wrappedValue.dismiss()
                        self.shouldDismissCameraView = true
                        print("[CameraPreviewView] PhotoExchangeConfirmationViewが閉じられました。CameraPreviewViewとCameraViewを閉じます。")
                    }
                )
            } else {
                // MARK: - エラーケース追加: savedAlbumPhotoがnilの場合
                Text("エラー: 写真が保存されていません。PhotoExchangeConfirmationViewを表示できません。")
                    .onAppear {
                        print("[CameraPreviewView] ❌ エラー: savedAlbumPhotoがnilのためPhotoExchangeConfirmationViewを表示できませんでした。")
                    }
            }
        }
        .fullScreenCover(isPresented: $navigateToPhotoDetail) {
            if let photo = self.photoToShowInDetail {
                PhotoDetailView(photo: photo, receivedUser: receivedUser)
            } else {
                // MARK: - エラーケース追加: photoToShowInDetailがnilの場合
                Text("エラー: 交換された写真の詳細をロードできませんでした。PhotoDetailViewを表示できません。")
                    .onAppear {
                        print("[CameraPreviewView] ❌ エラー: photoToShowInDetailがnilのためPhotoDetailViewを表示できませんでした。")
                    }
            }
        }
        .onAppear {
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
        // MARK: - 堅牢性向上: 多重タップ防止
        guard !isSavingPhoto else {
            print("[CameraPreviewView] ⚠️ 写真保存処理が既に進行中のためスキップ。")
            return
        }
        isSavingPhoto = true
        
        Task {
            do {
                let savedPhoto = try await AlbumManager.shared.saveAndUploadPhoto(
                    outerImage: mainImage,
                    innerImage: subImage,
                    receivedUser: receivedUser,
                    note: ""
                )
                print("[CameraPreviewView] ✅ 写真のクラウド保存とメタデータ登録が完了しました。")
                
                DispatchQueue.main.async {
                    self.isSavingPhoto = false
                    self.savedAlbumPhoto = savedPhoto

                    if let rootViewController = UIApplication.shared.topMostViewController {
                        interstitialAdManager.showAd(
                            from: rootViewController,
                            onPresented: {
                                print("[CameraPreviewView] ℹ️ 広告表示完了。")
                            },
                            onDismissed: {
                                self.navigateToConfirmation = true
                                print("[CameraPreviewView] ✅ 広告閉鎖（またはスキップ）、PhotoExchangeConfirmationView を開きます。")
                            }
                        )
                    } else {
                        // MARK: - エラー処理強化: topMostViewController取得失敗時のログとアラート
                        let errorMessage = "❗️ topMostViewController の取得に失敗しました。広告なしで画面遷移します。アプリの表示に問題がある可能性があります。"
                        print(errorMessage)
                        // ユーザーに視覚的に通知したい場合、アラートを表示することも検討
                        // self.saveAlertMessage = errorMessage
                        // self.showingSaveAlert = true
                        self.navigateToConfirmation = true
                    }
                }

            } catch let error as AlbumManager.PhotoError { // 特定のエラータイプで捕捉
                print("[CameraPreviewView] ❌ 写真保存失敗 (AlbumManager.PhotoError): \(error.localizedDescription) (Code: \((error as NSError).code))")
                DispatchQueue.main.async {
                    self.isSavingPhoto = false
                    self.saveAlertMessage = error.localizedDescription // AlbumManager.PhotoErrorのerrorDescriptionを使用
                    self.showingSaveAlert = true
                }
            } catch { // その他の不明なエラー
                print("[CameraPreviewView] ❌ 写真保存失敗 (不明なエラー): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isSavingPhoto = false
                    self.saveAlertMessage = "写真の保存中に予期せぬエラーが発生しました: \(error.localizedDescription)"
                    self.showingSaveAlert = true
                }
            }
        }
    }

    // MARK: - 堅牢性向上: アイコン読み込み関数を強化
    func loadImageSafely(named filename: String) -> UIImage {
        // まずアセットカタログからの読み込みを試行
        if let image = UIImage(named: filename) {
            return image
        }
        // 次にドキュメントディレクトリからの読み込みを試行
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        if let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        
        // どちらからも読み込めない場合、デフォルトのシステムアイコンを返す
        print("[CameraPreviewView] ⚠️ アイコン '\(filename)' が見つかりませんでした。デフォルトアイコンを表示します。")
        return UIImage(systemName: "person.circle.fill") ?? UIImage() // フォールバックとして空のUIImageも考慮
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
