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
                .navigationBarTitleDisplayMode(.inline)                   // ① 表示モード
                .toolbarBackground(.visible, for: .navigationBar)         // ② 背景を有効に
                .toolbarBackground(Color.black, for: .navigationBar)      // ③ 背景を黒に
                .toolbarColorScheme(.dark, for: .navigationBar)           // ④ タイトル/アイコンを白系に
                .toolbar { // <--- CHANGE: Use toolbar for clearer structure (optional, but clean)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu { // <--- CONSOLIDATE BUTTONS INTO A MENU
                            
                            // 1. 利用規約
                            Button("利用規約") {
                                showingTerms = true
                            }
                            
                            // 2. プライバシーポリシー
                            Button("プライバシーポリシー (PP)") {
                                showingPrivacy = true
                            }

                            // 3. 使い方
                            Button("使い方チュートリアル") {
                                showingTutorial = true
                            }

                            Divider()
                            
                            // 4. ログアウト
                            Button("ログアウト", role: .destructive) {
                                showingLogoutAlert = true
                            }
                            
                        } label: {
                            // アイコンを一つに集約し、混雑を解消
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                }
            }

        }
        // Sheets are correctly applied to the entire view hierarchy
        .sheet(isPresented: $showingTerms) {
            TermsAndPrivacyView(documentType: .terms)
        }
        .sheet(isPresented: $showingPrivacy) {
            TermsAndPrivacyView(documentType: .privacy)
        }
        .sheet(isPresented: $showingTutorial) {
            ShakeTutorialView()
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
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
#Preview {
    
}
