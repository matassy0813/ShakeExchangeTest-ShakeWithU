//
//  ContentView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/19.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var authManager = AuthManager.shared
    @State private var isFeedReady = false
    @State private var animateTransition = false

    var body: some View {
        // 認証済みかつ利用規約に同意済みの場合のみメインコンテンツを表示
        if authManager.isAuthenticated && authManager.hasAgreedToTerms {
            ZStack{
                if isFeedReady{
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
                    .scaleEffect(animateTransition ? 1 : 0.6)
                    .opacity(animateTransition ? 1 : 0)
                    .animation(.easeOut(duration: 1.2), value: animateTransition) // ← duration を 1.2秒に
                    .onAppear {
                        animateTransition = true
                    }
                    .accentColor(Color.yellow)
                }
                else {
                    LoadingView()
                }
            }
            .onAppear {
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // フェイク遅延（実際は FeedManager の状態監視でも良い）
                    isFeedReady = true
                }
            }
        } else if authManager.isAuthenticated && !authManager.hasAgreedToTerms {
            // 認証済みだが、利用規約に同意していない場合、同意画面を強制表示
            TermsAndPrivacyConsentView(isPresented: .constant(true)) // 強制表示のため .constant(true)
        } else {
            // 未認証の場合、AuthViewを表示
            AuthView()
        }
    }
}

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Circle()
                    .trim(from: 0, to: 0.8)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.purple, .blue, .pink]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
                    .onAppear { isAnimating = true }
                
                Text("Loading Feed...")
                    .foregroundColor(.white)
                    .font(.caption)
            }
        }
    }
}

#Preview {
    ContentView()
}

