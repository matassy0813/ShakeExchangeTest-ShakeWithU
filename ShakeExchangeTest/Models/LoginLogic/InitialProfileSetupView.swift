//
//  InitialProfileSettings.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/05.
//

import SwiftUI
import PhotosUI // アイコン選択用
import UIKit // UIImage用

struct InitialProfileSetupView: View {
    @ObservedObject var profileManager = ProfileManager.shared
    @Environment(\.dismiss) var dismiss // このビューを閉じるため

    @State private var draftName: String = ""
    @State private var draftDescription: String = ""
    @State private var draftLink: String = ""
    @State private var draftIcon: UIImage?
    @State private var imageSelection: PhotosPickerItem?
    @State private var showSaveError: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Setup Your Profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.top)

                    Text("Let's get started by setting up your public profile!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // アイコン選択
                    if let draftIcon = draftIcon {
                        Image(uiImage: draftIcon)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                            .shadow(radius: 5)
                    } else {
                        Image(systemName: "person.crop.circle.fill.badge.plus")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.gray)
                            .padding(5)
                            .background(Circle().fill(Color.gray.opacity(0.1)))
                    }

                    PhotosPicker(selection: $imageSelection, matching: .images) {
                        Text("Choose Profile Icon")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding(.vertical, 8)
                    }
                    .onChange(of: imageSelection) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                draftIcon = uiImage
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Name")
                            .font(.headline)
                        TextField("e.g. John Doe", text: $draftName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("About You")
                            .font(.headline)
                        TextField("Tell us about yourself...", text: $draftDescription, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...5)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Link (Optional)")
                            .font(.headline)
                        TextField("e.g. https://lit.link/yourname", text: $draftLink)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }

                    if let message = errorMessage {
                        Text(message)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: {
                        Task {
                            await saveProfile()
                        }
                    }) {
                        Text("Save Profile")
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(draftName.isEmpty) // 名前が空の場合は保存ボタンを無効化
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }

    // MARK: - プロフィール保存ロジック
    private func saveProfile() async {
        errorMessage = nil
        guard !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your name."
            return
        }

        // アイコン画像の保存
        var iconFilename: String = "profile_startImage" // デフォルトアイコン
        if let image = draftIcon {
            let filename = "profile_icon_\(UUID().uuidString).jpg"
            if let url = saveImageToDocuments(image: image, filename: filename) {
                iconFilename = url.lastPathComponent
            } else {
                errorMessage = "Failed to save icon image."
                return
            }
        }

        // currentUserを更新
        DispatchQueue.main.async {
            profileManager.currentUser.name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
            profileManager.currentUser.description = draftDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            profileManager.currentUser.link = draftLink.trimmingCharacters(in: .whitespacesAndNewlines)
            profileManager.currentUser.icon = iconFilename
            // UUIDはAuthManagerから設定されるため、ここでは変更しない
            // challengeStatus, recentPhotos は初期値のまま
        }
        
        // ProfileManagerのdidSetがFirestoreへの保存をトリガーする
        // 保存が完了するまで待つ
        await profileManager.saveProfileToFirestore()

        // プロフィール保存が完了したら、needsInitialProfileSetupフラグをfalseにする
        // これにより、ShakeExchangeTestAppのbodyが再評価され、ContentViewに遷移する
        AuthManager.shared.needsInitialProfileSetup = false // <-- この行を追加
        // dismiss() // このビューを閉じる (AuthManagerのフラグで自動遷移されるため不要)
    }

    // MARK: - Image Saving Helper (ProfileEditViewと同じ)
    private func saveImageToDocuments(image: UIImage, filename: String) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }

        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)

        do {
            try data.write(to: url)
            return url
        } catch {
            print("❌ Failed to save image: \(error.localizedDescription)")
            return nil
        }
    }
}
