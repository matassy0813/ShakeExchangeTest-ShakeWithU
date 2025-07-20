//
//  ShakeButtonView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//
import SwiftUI

struct ShakeButtonView: View {
    @State private var animate = false
    @State private var foundFriend = false
    @State private var showBanner = false
    @State private var navigateToFriend = false
    
    @State private var foundFriendName = "Emily"
    @State private var foundFriendImage = "sample_icon1" // アイコン名
    
    @State private var bannerTimer: Timer? = nil

    @State private var receivedUser: CurrentUser? = nil
    
    @ObservedObject var profileManager = ProfileManager.shared

    @State private var finalIcon: String = "profile_startImage" // 初期値を使っておく
    
    let dummyUser = CurrentUser(
        uuid: "dummy",
        name: "Dummy",
        description: "",
        icon: "profile_startImage",
        link: "",
        challengeStatus: 0,
        recentPhotos: []
    )

    // このビューを閉じるためのEnvironmentプロパティ
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                Color.blue.opacity(0.1).ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    // 中央アニメーション
                    ZStack {
                        Circle()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                            .scaleEffect(animate ? 1.4 : 0.8)
                            .opacity(animate ? 0 : 1)
                            .animation(Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: animate)

                        Circle()
                            .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                            .scaleEffect(animate ? 1.2 : 0.6)
                            .opacity(animate ? 0 : 1)
                            .animation(Animation.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: animate)

                        Image(systemName: "person.2.wave.2.fill")
                            .resizable()
                            .frame(width: 60, height: 45)
                            .foregroundColor(.blue)
                    }

                    // 状態テキスト
                    Text(foundFriend ? "Friend Found!" : "Connecting...")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .animation(.easeInOut, value: foundFriend)

                    Spacer()

                    // シェイクボタン
                    Button(action: {
                        animate = true
                        foundFriend = false
                        showBanner = false

                        print("[ShakeButtonView] ボタン押下 → 通信開始")
                        MultipeerManager.shared.detectHandshake()
                    }) {
                        Text("Shake to Connect")
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    .padding(.horizontal)
                }

                // 上部から降りるバナー風
                if showBanner {
                    VStack {
                        Button(action: {
                            if receivedUser != nil {
                                navigateToFriend = true // FriendFoundViewへ遷移
                            } else {
                                print("[ShakeButtonView] ⚠️ バナータップされたが receivedUser が nil")
                            }
                        }) {
                            HStack {
                                Image(systemName: "hands.sparkles.fill")
                                    .foregroundColor(.blue)
                                Text("Connected with \(foundFriendName)!")
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 3)
                            .padding()
                        }

                        Spacer()
                    }
                    .transition(.move(edge: .top))
                }

                // NavigationLink
                NavigationLink(
                    destination: FriendFoundView(receivedUser: receivedUser ?? dummyUser),
                    isActive: $navigateToFriend
                ) {
                    EmptyView()
                }
                .onDisappear { // FriendFoundViewが閉じられたら
                    // presentationMode.wrappedValue.dismiss() // この行を削除またはコメントアウト
                    print("[ShakeButtonView] FriendFoundViewが閉じられました。")
                }
            }
            .onAppear {
                animate = true
                foundFriend = false
                showBanner = false
                navigateToFriend = false
                receivedUser = nil
                foundFriendName = ""
                foundFriendImage = "profile_startImage"
                
                print("[ShakeButtonView] 表示開始 & 状態初期化")

                MultipeerManager.shared.onReceiveUser = { user in
                    print("[ShakeButtonView] データ受信: \(user.uuid)")
                    foundFriendName = user.name
                    foundFriendImage = user.icon
                    receivedUser = user
                    foundFriend = true
                    withAnimation {
                        showBanner = true
                    }
                }
            }

            .onDisappear {
                print("[ShakeButtonView] 表示終了 → 通信停止")
                MultipeerManager.shared.stop()
                MultipeerManager.shared.onReceiveUser = nil
            }
            .onChange(of: MultipeerManager.shared.isHandshakeDetected) { newValue in
                if newValue {
                    handleShake()
                }
            }
            .onChange(of: showBanner) { newValue in
                if newValue {
                    // タイマーを設定
                    bannerTimer?.invalidate()
                    bannerTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                        // ✅ すでに遷移が始まっている場合は処理を中断
                        guard !navigateToFriend else {
                            print("[ShakeButtonView] ✅ ナビゲーション中なのでタイマーリセットなし")
                            return
                        }

                        if showBanner {
                            withAnimation {
                                showBanner = false
                            }
                            foundFriend = false
                            receivedUser = nil
                            print("[ShakeButtonView] ⏱️ バナータイムアウト → 通信切断＆再探索")

                            MultipeerManager.shared.stop()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                MultipeerManager.shared.detectHandshake()
                            }
                        }
                    }
                } else {
                    bannerTimer?.invalidate()
                }
            }
        }
    }
    
    func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    func handleShake() {
        print("[ShakeButtonView] シェイク検知 → 通信処理")
        MultipeerManager.shared.startAdvertising()
        MultipeerManager.shared.startBrowsing()

        if let data = try? JSONEncoder().encode(profileManager.currentUser) {
            MultipeerManager.shared.send(data: data)
            print("[ShakeButtonView] データ送信: \(profileManager.currentUser.uuid)")
        }
    }
}
