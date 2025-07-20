//
//  FriendRecentRankingView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/15.
//

import SwiftUI

struct FriendRecentRankingView: View {
    @ObservedObject var manager = FriendRecentRankingManager()
    @EnvironmentObject var friendManager: FriendManager
    @State private var selectedTab = 0

    var body: some View {
        VStack {
            Picker(selection: $selectedTab, label: Text("ランキングタイプ")) {
                Text("最近1週間").tag(0)
                Text("全期間").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            if selectedTab == 0 {
                RankingListView(friends: manager.topFriends, title: "👑 最近よく会ってる人 TOP5")
                    .onAppear {
                        manager.fetchTopFriends(from: friendManager.friends)
                    }
            } else {
                RankingListView(friends: manager.allTimeTopFriends, title: "🏆 全期間の再会 TOP5")
                    .onAppear {
                        manager.fetchAllTimeTopFriends(from: friendManager.friends)
                    }
            }

            Spacer()
        }
        .padding()
    }
}

struct RankingListView: View {
    let friends: [Friend]
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.bold())

            if friends.isEmpty {
                Text("🥲 まだ十分なデータがありません…\nもっと交流してみて！")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(friends.indices, id: \.self) { index in
                    let friend = friends[index]
                    HStack {
                        Text("#\(index + 1)")
                            .font(.title.bold())
                            .foregroundColor(rankColor(index))
                            .frame(width: 50)

                        if let uiImage = loadUserIcon(named: friend.icon) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        } else {
                            Image(friend.icon)
                                .resizable()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        }

                        VStack(alignment: .leading) {
                            Text(friend.nickname)
                                .font(.headline)
                            Text("再会 \(friend.encounterCount ?? 0) 回")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(gradient: Gradient(colors: [rankColor(index).opacity(0.2), Color.white.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                    )
                }
            }
        }
    }

    func loadUserIcon(named filename: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return .gray
        case 2: return .orange
        default: return .blue
        }
    }
}

