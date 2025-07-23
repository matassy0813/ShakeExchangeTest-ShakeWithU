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
        NavigationView {
            VStack {
                // タイトルと並べ替え
                HStack {
                    Text("Friends")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    Spacer()
                    Picker("Sort", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                }
                .padding(.horizontal)
                
                // 検索バー
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always)) {
                    // 検索候補 (オプション)
                    ForEach(filteredAndSortedFriends.prefix(5)) { friend in
                        Text(friend.name).searchCompletion(friend.name)
                    }
                }
                .foregroundColor(.white) 

                // リスト
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if filteredAndSortedFriends.isEmpty {
                            ContentUnavailableView(
                                "No Friends Yet",
                                systemImage: "person.3.fill",
                                description: Text("Shake your phone with someone to add them to your network!")
                            )
                            .padding(.top, 50)
                        } else {
                            ForEach(filteredAndSortedFriends) { friend in
                                // recentPhotos 引数を削除
                                NavigationLink(destination: FriendProfileView(friend: friend)) {
                                    FriendCardView(friend: friend)
                                }
                            }
                        }
                    }
                    .padding(.top)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("") // カスタムタイトルを使用するため空にする
            .navigationBarHidden(true) // カスタムタイトルを使用するため非表示にする
        }
    }
}

