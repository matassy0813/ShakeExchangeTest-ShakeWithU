//
//  FriendRecentRankingManager.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/15.
//

import Foundation
import FirebaseFirestore

class FriendRecentRankingManager: ObservableObject {
    @Published var topFriends: [Friend] = []

    func fetchTopFriends(from allFriends: [Friend]) {
        let recentDateThreshold = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let ranked = allFriends.filter { friend in
            guard let date = formatter.date(from: friend.lastInteracted) else { return false }
            return date >= recentDateThreshold
        }
        .sorted {
            ($0.encounterCount ?? 0) > ($1.encounterCount ?? 0)
        }

        DispatchQueue.main.async {
            self.topFriends = Array(ranked.prefix(5))
        }
    }
}
