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
        ZStack{
            Color.black.ignoresSafeArea()
            VStack {
                Picker(selection: $selectedTab, label: Text("ランキングタイプ")) {
                    Text("最近1週間").tag(0)
                    Text("全期間").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 100) 
                
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
            .foregroundColor(.white)
            .padding()
        }
        
    }
}

struct RankingListView: View {
    let friends: [Friend]
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.bold())
                .foregroundColor(.white)

            if friends.isEmpty {
                Text("🥲 まだ十分なデータがありません…\nもっと交流してみて！")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.6))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.03))
                    )
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
                                .foregroundColor(.white)
                            Text("再会 \(friend.encounterCount ?? 0) 回")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [rankColor(index).opacity(0.2), Color.black.opacity(0.3)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .shadow(color: Color.white.opacity(0.05), radius: 4, x: 0, y: 2)
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

