//
//  AuthView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/05.
//

import SwiftUI

struct AuthView: View {
    @ObservedObject var authManager = AuthManager.shared //
    @State private var email: String = "" //
    @State private var password: String = "" //
    @State private var isSigningUp: Bool = false // true: 新規登録, false: ログイン
    @State private var isLoading: Bool = false //
    @State private var showingTermsAndPrivacy: Bool = false // 利用規約・プライバシーポリシー同意画面表示フラグ

    var body: some View { //
        NavigationView { //
            VStack { //
                Spacer() //

                Text("Welcome to ShakeExchange!") //
                    .font(.largeTitle) //
                    .fontWeight(.bold) //
                    .padding(.bottom, 40) //

                VStack(spacing: 20) { //
                    TextField("Email", text: $email) //
                        .keyboardType(.emailAddress) //
                        .autocapitalization(.none) //
                        .textFieldStyle(RoundedBorderTextFieldStyle()) //
                        .padding(.horizontal) //

                    SecureField("Password", text: $password) //
                        .textFieldStyle(RoundedBorderTextFieldStyle()) //
                        .padding(.horizontal) //

                    if let errorMessage = authManager.errorMessage { //
                        Text(errorMessage) //
                            .foregroundColor(.red) //
                            .font(.caption) //
                            .multilineTextAlignment(.center) //
                            .padding(.horizontal) //
                    }

                    Button(action: { //
                        isLoading = true //
                        Task { //
                            if isSigningUp { //
                                _ = await authManager.signUp(email: email, password: password) //
                            } else { //
                                _ = await authManager.signIn(email: email, password: password) //
                            }
                            isLoading = false //
                        }
                    }) {
                        Text(isSigningUp ? "Sign Up" : "Sign In") //
                            .fontWeight(.bold) //
                            .padding() //
                            .frame(maxWidth: .infinity) //
                            .background(Color.blue) //
                            .foregroundColor(.white) //
                            .cornerRadius(10) //
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty) //
                    .padding(.horizontal) //

                    Button(action: { //
                        isSigningUp.toggle() //
                        authManager.errorMessage = nil // エラーメッセージをクリア
                    }) {
                        Text(isSigningUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up") //
                            .font(.footnote) //
                            .foregroundColor(.gray) //
                    }
                }
                .padding() //
                .background(Color.white.opacity(0.8)) //
                .cornerRadius(15) //
                .shadow(radius: 5) //
                .padding(.horizontal, 20) //

                Spacer() //
            }
            .background(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()) //
            .navigationTitle("") //
            .navigationBarHidden(true) //
        }
        .fullScreenCover(isPresented: $showingTermsAndPrivacy) { //
            if !authManager.hasAgreedToTerms { //
                // TermsAndPrivacyConsentView(isPresented: $showingTermsAndPrivacy) // 未定義のためコメントアウト
            }
        }
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in //
            // 認証されたが、まだ同意していない場合、同意画面を表示
            if isAuthenticated && !authManager.hasAgreedToTerms { //
                showingTermsAndPrivacy = true //
            }
            // ここでの checkSessionValidity() の呼び出しは削除
            // 代わりに SocialNetworkView の onAppear で ProfileManager のロード後に呼び出す
        }
    }
}
