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

    var body: some View {
        NavigationView {
            FeedView() // ← FeedView を使う
                .navigationTitle("Shake")
                .navigationBarItems(
                    // カメラボタンと紙飛行機ボタンを削除
                    trailing: HStack {
                        Button(action: {
                            showingTerms = true
                        }) {
                            Text("規約")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.blue.opacity(0.1)))
                                .foregroundColor(.blue)
                        }
                        .sheet(isPresented: $showingTerms) {
                            TermsAndPrivacyView(documentType: .terms)
                        }

                        Button(action: {
                            showingPrivacy = true
                        }) {
                            Text("PP") // Privacy Policy の略
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.purple.opacity(0.1)))
                                .foregroundColor(.purple)
                        }
                        .sheet(isPresented: $showingPrivacy) {
                            TermsAndPrivacyView(documentType: .privacy)
                        }
                    }
                )
        }
    }
}

