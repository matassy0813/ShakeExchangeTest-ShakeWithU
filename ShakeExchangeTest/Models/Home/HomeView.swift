//
//  HomeView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//
import SwiftUI

// MARK: - Home Feed
struct HomeView: View {
    @State private var showingTerms: Bool = false
    @State private var showingPrivacy: Bool = false
    @State private var showingTutorial: Bool = false
    @State private var isLoggingOut = false
    @State private var showingLogoutAlert = false

    var body: some View {
        NavigationView {
            FeedView() // ← FeedView を使う
                .background(Color.black)
                .navigationTitle("Main")
                .foregroundColor(.white)
                .navigationBarItems(
                    // カメラボタンと紙飛行機ボタンを削除
                    trailing: HStack {
                        Button(action: {
                            showingTerms = true
                        }) {
                            Text("規約")
                                .font(.caption2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                )
                                .foregroundColor(.white)
                        }
                        .sheet(isPresented: $showingTerms) {
                            TermsAndPrivacyView(documentType: .terms)
                        }

                        Button(action: {
                            showingPrivacy = true
                        }) {
                            Text("PP") // Privacy Policy の略
                                .font(.caption2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.pink.opacity(0.3), Color.orange.opacity(0.3)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                )
                                .foregroundColor(.white)
                        }
                        .sheet(isPresented: $showingPrivacy) {
                            TermsAndPrivacyView(documentType: .privacy)
                        }
                        
                        Button(action: {
                            showingTutorial = true
                        }) {
                            Text("使い方")
                                .font(.caption2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.green.opacity(0.3), Color.teal.opacity(0.3)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                )
                                .foregroundColor(.white)
                        }
                        .sheet(isPresented: $showingTutorial) {
                            ShakeTutorialView()
                        }
                        
                        Button(action: {
                            showingLogoutAlert = true
                        }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.caption)
                                .padding(8)
                                .background(Color.red.opacity(0.2))
                                .clipShape(Circle())
                                .foregroundColor(.red)
                        }
                        .alert(isPresented: $showingLogoutAlert) {
                            Alert(
                                title: Text("ログアウトしますか？"),
                                message: Text("現在のアカウントからログアウトします。"),
                                primaryButton: .destructive(Text("ログアウト")) {
                                    Task {
                                        isLoggingOut = true
                                        _ = await AuthManager.shared.signOut()
                                        isLoggingOut = false
                                    }
                                },
                                secondaryButton: .cancel()
                            )
                        }

                    }
                )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
#Preview {
    
}
