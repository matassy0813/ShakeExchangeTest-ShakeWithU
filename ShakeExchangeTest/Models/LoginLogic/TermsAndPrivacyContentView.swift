//
//  TermsAndPrivacyContentView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/11.
//

import SwiftUI

struct TermsAndPrivacyConsentView: View {
    @ObservedObject var authManager = AuthManager.shared
    @Binding var isPresented: Bool // AuthViewから渡されるバインディング
    @State private var hasCheckedTerms: Bool = false
    @State private var hasCheckedPrivacy: Bool = false
    @State private var showingTermsSheet: Bool = false
    @State private var showingPrivacySheet: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "hand.raised.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                    .padding(.bottom, 20)

                Text("本アプリのご利用には、\n利用規約とプライバシーポリシーへの同意が必要です。")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // 利用規約のチェックボックスとリンク
                HStack {
                    Toggle(isOn: $hasCheckedTerms) {
                        EmptyView() // トグル自体のラベルは表示しない
                    }
                    .labelsHidden() // iOS 15+ でラベルを非表示にする
                    .toggleStyle(CheckboxToggleStyle()) // カスタムスタイルを適用

                    Text("利用規約に同意する")
                        .onTapGesture {
                            hasCheckedTerms.toggle() // テキストタップでトグル
                        }

                    Button("確認") {
                        showingTermsSheet = true
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.gray.opacity(0.1)))
                    .foregroundColor(.gray)
                    .sheet(isPresented: $showingTermsSheet) {
                        TermsAndPrivacyView(documentType: .terms)
                    }
                }

                // プライバシーポリシーのチェックボックスとリンク
                HStack {
                    Toggle(isOn: $hasCheckedPrivacy) {
                        EmptyView()
                    }
                    .labelsHidden()
                    .toggleStyle(CheckboxToggleStyle())

                    Text("プライバシーポリシーに同意する")
                        .onTapGesture {
                            hasCheckedPrivacy.toggle()
                        }

                    Button("確認") {
                        showingPrivacySheet = true
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.gray.opacity(0.1)))
                    .foregroundColor(.gray)
                    .sheet(isPresented: $showingPrivacySheet) {
                        TermsAndPrivacyView(documentType: .privacy)
                    }
                }

                Button(action: {
                    // 同意状態をAuthManagerに保存
                    authManager.hasAgreedToTerms = true
                    authManager.saveTermsAgreementStatus()
                    isPresented = false // 同意画面を閉じる
                }) {
                    Text("同意してアプリを始める")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(hasCheckedTerms && hasCheckedPrivacy ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!(hasCheckedTerms && hasCheckedPrivacy)) // 両方チェックされるまで無効
                .padding(.horizontal, 20)

                Spacer()
            }
            .navigationTitle("同意のお願い")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - カスタムトグルスタイル (チェックボックス風)
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(configuration.isOn ? .blue : .gray)
                .onTapGesture {
                    configuration.isOn.toggle()
                }
            configuration.label
        }
    }
}
