//
//  ContentView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/19.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var authManager = AuthManager.shared

    var body: some View {
        // 認証済みかつ利用規約に同意済みの場合のみメインコンテンツを表示
        if authManager.isAuthenticated && authManager.hasAgreedToTerms {
            TabView {
                // HomeView を最初のタブとして維持
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }

                // AlbumMainView を維持
                AlbumMainView()
                    .tabItem {
                        Image(systemName: "photo.on.rectangle")
                        Text("Album")
                    }

                // ShakeButtonView を維持
                ShakeButtonView()
                    .tabItem {
                        Image(systemName: "dot.circle")
                        Text("SHAKE")
                    }

                // FriendMainView を維持
                FriendMainView()
                    .tabItem {
                        Image(systemName: "person.2.fill")
                        Text("Friends")
                    }
                
                // 新たに SocialNetworkView を追加
                SocialNetworkView() // ネットワークグラフのビュー
                    .tabItem {
                        Image(systemName: "network") // ネットワークを表すアイコン
                        Text("Network") // タブの表示名
                    }

                // ProfileView を維持
                ProfileView()
                    .tabItem {
                        Image(systemName: "person.crop.circle")
                        Text("Profile")
                    }
                
                FriendRecentRankingView()
                    .environmentObject(FriendManager.shared)
                    .tabItem {
                        Image(systemName: "chart.bar.xaxis")
                        Text("Ranking")
                    }
            }
            .background(Color.black.ignoresSafeArea()) // 🔥 全体黒ベースに
            .tint(.white)
        } else if authManager.isAuthenticated && !authManager.hasAgreedToTerms {
            // 認証済みだが、利用規約に同意していない場合、同意画面を強制表示
            TermsAndPrivacyConsentView(isPresented: .constant(true)) // 強制表示のため .constant(true)
        } else {
            // 未認証の場合、AuthViewを表示
            AuthView()
        }
    }
}


#Preview {
    ContentView()
}

