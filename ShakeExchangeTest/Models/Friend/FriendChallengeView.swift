//
//  FriendChallengeView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/23.
//

import SwiftUI

struct FriendChallengeView: View {
    let challengeStatus: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🔥 Challenge")
                .font(.headline)

            ProgressView(value: Double(challengeStatus), total: 30)
                .accentColor(.orange)

            Text("Streak: \(challengeStatus) days")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
    }
}
