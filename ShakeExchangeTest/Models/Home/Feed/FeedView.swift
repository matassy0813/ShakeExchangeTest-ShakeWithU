//
//  Untitled.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//
import SwiftUI

struct FeedView: View {
    @ObservedObject var feedManager = FeedManager.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if feedManager.isLoading {
                        ProgressView("Loading Feed...")
                            .padding()
                    } else if let error = feedManager.errorMessage {
                        Text("Error loading feed: \(error)")
                            .foregroundColor(.red)
                            .padding()
                    } else if feedManager.feed.isEmpty {
                        ContentUnavailableView(
                            "No Feed Yet",
                            systemImage: "photo.stack.fill",
                            description: Text("Connect with friends and take photos to see them here!")
                        )
                        .padding(.top, 50)
                        .foregroundColor(.gray)
                    } else {
                        ForEach(feedManager.feed) { item in
                            switch item {
                            case .entry(let entry):
                                FeedItemView(feedEntry: entry)
                            case .ad:
                                AdView()
                                    .frame(height: 200)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.yellow.opacity(0.2), Color.white.opacity(0.05)]),
                                            startPoint: .top,
                                            endPoint: .bottom)
                                    )
                                    .cornerRadius(12)
                                    .shadow(color: .yellow.opacity(0.1), radius: 6)
                            }
                        }
                    }
                }
                .padding()
                .foregroundColor(.white) // 全体白基調に
            }
            // MARK: - Pull-to-Refresh 機能を追加
            .refreshable {
                // 認証済みでuserIdが存在する場合のみフィードをロード
                if AuthManager.shared.isAuthenticated, let userId = AuthManager.shared.userId {
                    print("[FeedView] 🔄 Pull-to-Refresh: フィードを更新します。")
                    await feedManager.loadFeed(for: userId, friends: FriendManager.shared.friends)
                } else {
                    print("[FeedView] ℹ️ Pull-to-Refresh: 未認証のためフィード更新をスキップします。")
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Feed")
//            .navigationBarItems(
//                leading: Image(systemName: "camera"), // カメラアイコン
//                trailing: Image(systemName: "paperplane") // メッセージアイコン
//            )
        }
    }
}

