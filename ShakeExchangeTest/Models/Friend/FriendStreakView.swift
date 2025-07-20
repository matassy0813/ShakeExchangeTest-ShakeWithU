//
//  FriendStreakView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/16.
//

import SwiftUI

struct FriendStreakView: View {
    let streakCount: Int
    @State private var pulseEffect: Bool = false
    @State private var confettiTrigger: Int = 0 // Used to trigger confetti on appear/change

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("🔥 Streak")
                .font(.headline)
                .foregroundColor(.primary)

            ZStack {
                // Background pulse/glow for higher streaks
                if streakCount >= 7 {
                    Circle()
                        .fill(streakColor(streakCount).opacity(0.2))
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulseEffect ? 1.2 : 1.0)
                        .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseEffect)
                }

                // Main streak display
                VStack {
                    Text("\(streakCount)")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(streakColor(streakCount))
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 3)

                    Text("Day\(streakCount == 1 ? "" : "s")")
                        .font(.title2.bold())
                        .foregroundColor(.secondary)
                }
            }
            .onAppear {
                pulseEffect = true
                if streakCount > 0 { // Trigger confetti if there's a streak
                    confettiTrigger += 1
                }
            }
            .onChange(of: streakCount) { newCount in
                if newCount > 0 { // Trigger confetti if streak changes and is positive
                    confettiTrigger += 1
                }
            }
        }
        .padding()
        .background(Color.clear) // Transparent background
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 5)
        .padding(.horizontal)
    }

    private func streakColor(_ streak: Int) -> Color {
        if streak >= 100 {
            return .purple // Legendary streak
        } else if streak >= 30 {
            return .red // Epic streak
        } else if streak >= 7 {
            return .orange // Solid streak
        } else {
            return .gray // Starting streak
        }
    }
}
