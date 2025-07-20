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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("👑 最近よく会ってる人 TOP5")
                .font(.title2.bold())
            

            if manager.topFriends.isEmpty {
                Text("🥲 まだ十分なデータがありません…\nもっと交流してみて！")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(manager.topFriends.indices, id: \.self) { index in
                    let friend = manager.topFriends[index]
                    HStack {
                        Text("#\(index + 1)")
                            .font(.title.bold()) // Larger font for rank
                            .foregroundColor(rankColor(index))
                            .frame(width: 50) // Adjust frame to accommodate larger font

                        if let uiImage = loadUserIcon(named: friend.icon) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        } else {
                            Image(friend.icon) // fallback
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
                    // Enhanced background with gradient and shadow
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(gradient: Gradient(colors: [rankColor(index).opacity(0.2), Color.white.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                    )
                    .cornerRadius(12) // Redundant due to background modifier, but harmless
                }
            }


            Spacer()
        }
        .padding()
        .onAppear {
            manager.fetchTopFriends(from: friendManager.friends)
        }
    }
    
    func loadUserIcon(named filename: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .yellow // Gold
        case 1: return .gray // Silver
        case 2: return .orange // Bronze
        default: return .blue
        }
    }
}
