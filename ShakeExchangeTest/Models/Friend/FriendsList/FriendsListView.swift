//
//  FriendListView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//

import SwiftUI

enum SortOption: String, CaseIterable {
    case recentlyAdded = "Added Recently"
    case recentlyInteracted = "Recently Interacted"
    case alphabetical = "A-Z"
}

struct FriendsListView: View {
    @ObservedObject var friendManager = FriendManager.shared
    @State private var sortOption: SortOption = .recentlyAdded
    @State private var searchText: String = "" // 検索テキスト

    private let contentMaxWidth: CGFloat = 300
    
    // 検索とソートを適用した友達リスト
    var filteredAndSortedFriends: [Friend] {
        var filtered = friendManager.friends

        // 検索フィルター
        if !searchText.isEmpty {
            filtered = filtered.filter { friend in
                friend.name.localizedCaseInsensitiveContains(searchText) ||
                friend.nickname.localizedCaseInsensitiveContains(searchText) ||
                friend.description.localizedCaseInsensitiveContains(searchText)
            }
        }

        // ソート
        switch sortOption {
        case .recentlyAdded:
            return filtered.sorted(by: { $0.addedDate > $1.addedDate })
        case .recentlyInteracted:
            return filtered.sorted(by: { $0.lastInteracted > $1.lastInteracted })
        case .alphabetical:
            return filtered.sorted(by: { $0.name < $1.name })
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景：暗いグラデ＋大きめボケ模様で奥行き
                LinearGradient(colors: [.black, .black.opacity(0.92)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                // さりげない光の輪（背景装飾）
                Circle()
                    .fill(LinearGradient(colors: [.blue.opacity(0.18), .purple.opacity(0.08)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .blur(radius: 120)
                    .frame(width: 420, height: 420)
                    .offset(x: -140, y: -240)

                VStack(spacing: 12) {
                    // ===== ヘッダ =====
                    HStack {
                        Text("Friends")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        Spacer()
                        Picker("Sort", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.08), lineWidth: 0.8)
                    )
                    .frame(maxWidth: contentMaxWidth)                     // ← 横幅を制限
                    .frame(maxWidth: .infinity, alignment: .center)       // ← 画面中央に配置
                    .padding(.top, 8)

                    // 検索バー（そのまま）
                    HStack { Spacer() }
                        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))

                    // ===== リスト =====
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            if filteredAndSortedFriends.isEmpty {
                                ContentUnavailableView(
                                    "No Friends Yet",
                                    systemImage: "person.3.fill",
                                    description: Text("Shake your phone with someone to add them to your network!")
                                )
                                .padding(.top, 50)
                            } else {
                                ForEach(filteredAndSortedFriends) { friend in
                                    // カードを中央寄せ＋横幅制限
                                    HStack {
                                        Spacer(minLength: 0)
                                        NavigationLink(destination: FriendProfileView(friend: friend)) {
                                            FriendCardView(friend: friend)
                                                .frame(maxWidth: contentMaxWidth)        // ← 横幅を制限
                                        }
                                        .buttonStyle(CardPressedStyle())
                                        Spacer(minLength: 0)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 16)   // ← 画面端とのマージン（安全域も確保）
            }
            .navigationTitle("")        // カスタムヘッダを使う
            .navigationBarHidden(true)
        }
    }
    struct CardPressedStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
        }
    }
}

