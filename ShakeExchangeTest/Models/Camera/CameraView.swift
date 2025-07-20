//
//  CameraView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/21.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject var cameraManager = CameraManager()
    @Environment(\.presentationMode) var presentationMode // このビューを閉じるため

    // outer/inner の最終保存用
    @State private var outer: UIImage? = nil
    @State private var inner: UIImage? = nil
    @State private var navigateToPreview = false

    var receivedUser: CurrentUser // FriendFoundViewから渡される相手のユーザー情報
    var friendName: String
    var friendIcon: String
    var userIcon: String

    var body: some View {
        ZStack {
            if let previewLayer = cameraManager.previewLayer {
                CameraPreview(previewLayer: previewLayer)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 20)
            }

            VStack {
                HStack {
                    Button(action: {
                        cameraManager.flipCamera()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                }
                Spacer()
                captureButton()
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .fullScreenCover(isPresented: $navigateToPreview) {
            // capturedOuter/inner が nil でないか確認してから渡す
            CameraPreviewView(
                mainImage: Binding(get: { self.outer ?? UIImage() },
                                    set: { self.outer = $0 }),
                subImage: Binding(get: { self.inner ?? UIImage() },
                                   set: { self.inner = $0 }),
                receivedUser: receivedUser, // ここで receivedUser を渡す
                friendName: receivedUser.name,
                friendIcon: receivedUser.icon,
                userIcon: userIcon
            )
//            .onDisappear { // CameraPreviewViewが閉じられたら
//                presentationMode.wrappedValue.dismiss() // CameraViewを閉じる
//                print("[CameraView] 📷 CameraPreviewViewが閉じられたため、CameraViewを閉じます。")
//            }
            .onAppear {
                print("[CameraView] 🔵 fullScreenCover 渡し時 outer: \(String(describing: outer?.size))")
                print("[CameraView] 🔵 fullScreenCover 渡し時 inner: \(String(describing: inner?.size))")
            }
        }
    }

    private func captureButton() -> some View {
        Button(action: {
            captureBeRealStylePhoto()
        }) {
            Circle()
                .fill(Color.white)
                .frame(width: 70, height: 70)
                .overlay(Circle().stroke(Color.gray, lineWidth: 3))
        }
        .padding()
    }

    private func captureBeRealStylePhoto() {
        let startPosition = cameraManager.currentCamera

        cameraManager.capturePhoto { firstImage in
            guard let firstImage = firstImage else {
                print("❌ Outer 撮影失敗")
                return
            }

            DispatchQueue.main.async {
                if startPosition == .back {
                    self.outer = firstImage
                } else {
                    self.inner = firstImage
                }

                self.cameraManager.flipCamera()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.cameraManager.capturePhoto { secondImage in
                        guard let secondImage = secondImage else {
                            print("❌ Inner 撮影失敗")
                            return
                        }

                        DispatchQueue.main.async {
                            if startPosition == .back {
                                self.inner = secondImage
                            } else {
                                self.outer = secondImage
                            }

                            print("[CameraView] ✅ 2枚撮影完了 outer: \(String(describing: self.outer?.size)) inner: \(String(describing: self.inner?.size))")

                            // outer / inner の両方が確実に存在するまで待機
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                if let outer = self.outer, let inner = self.inner,
                                   outer.cgImage != nil, inner.cgImage != nil {
                                    print("[CameraView] 🔥 outer/inner 両方メモリOK → 遷移開始")
                                    self.navigateToPreview = true
                                } else {
                                    print("[CameraView] ⚠️ メモリ未反映 → 再試行必要")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


#Preview {
    let sampleUser = CurrentUser(
        uuid: "sample_user_uuid",
        name: "Yuma",
        description: "音楽好きな友達です！",
        icon: "profile_icon_sample.jpg",
        link: "https://instagram.com/sample_user",
        challengeStatus: 18,
        recentPhotos: []
    )
    
    CameraView(
        receivedUser: sampleUser,
        friendName: sampleUser.name,
        friendIcon: sampleUser.icon,
        userIcon: "profile_start_image"
    )
}
