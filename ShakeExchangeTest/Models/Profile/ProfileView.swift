//
//  ProfileView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//
import SwiftUI

struct ProfileView: View {
    @ObservedObject var profileManager = ProfileManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // アイコン表示
                    if let uiImage = loadUserIcon(named: profileManager.currentUser.icon) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    } else {
                        // アイコンが読み込めない場合のフォールバック（システムアイコン）
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .foregroundColor(.gray)
                            .shadow(radius: 4)
                    }

                    Text(profileManager.currentUser.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("@\(profileManager.currentUser.uuid)")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Text(profileManager.currentUser.description)
                        .font(.body)
                        .multilineTextAlignment(.center)

                    // Linkの安全なアンラップ
                    if let url = URL(string: profileManager.currentUser.link), UIApplication.shared.canOpenURL(url) {
                        Link(destination: url) {
                            Text(profileManager.currentUser.link)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue, lineWidth: 1)
                                )
                        }
                    } else if !profileManager.currentUser.link.isEmpty {
                        // 無効なURLだが空ではない場合（リンクとしてタップできないがテキストは表示）
                        Text(profileManager.currentUser.link)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    }


                    VStack(spacing: 4) {
                        HStack {
                            Text("Challenges")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("Streak: \(profileManager.currentUser.challengeStatus) days")
                        }

                        ProgressView(value: Double(profileManager.currentUser.challengeStatus), total: 30)
                            .progressViewStyle(LinearProgressViewStyle(tint: .black))

                        Text("\(profileManager.currentUser.challengeStatus) / 30")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)

                    Divider()

                    Text("Recent Photos")
                        .font(.headline)

                    // RecentPhotosの表示 (AlbumImageViewを使用)
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 8) {
                        ForEach(profileManager.currentUser.recentPhotos.prefix(6), id: \.id) { photo in
                            AlbumImageView(storagePath: photo.outerImage) // AlbumImageViewを使用
                                .frame(width: 100, height: 100)
                                .clipped()
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarItems(trailing:
                NavigationLink(destination: ProfileEditView(user: $profileManager.currentUser)) {
                    Text("Edit")
                        .foregroundColor(.blue)
                }
            )
        }
    }
    
    // MARK: - アイコン画像読み込みヘルパー (ProfileManagerからコピー)
    private func loadUserIcon(named filename: String) -> UIImage? {
        // 1. アセットカタログからの読み込みを試行
        if let image = UIImage(named: filename) {
            return image
        }
        // 2. ドキュメントディレクトリからの読み込みを試行
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
}


