//
//  FriendCardView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/23.
//

import SwiftUI

struct FriendCardView: View {
    let friend: Friend
    @State private var animateGlow: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // ✅ ローカルアイコン読込対応
            ZStack {
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

                // Streak effect overlay
                if let streak = friend.streakCount, streak >= 7 {
                    Circle()
                        .stroke(streakColor(streak), lineWidth: 3)
                        .frame(width: 58, height: 58) // Slightly larger than icon
                        .scaleEffect(animateGlow ? 1.05 : 1.0)
                        .opacity(animateGlow ? 0.8 : 0.5)
                        .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: animateGlow)
                        .onAppear {
                            animateGlow = true
                        }
                        .overlay(
                            Circle()
                                .fill(streakColor(streak).opacity(animateGlow ? (streak >= 30 ? 0.2 : 0.1) : 0.05))
                                .frame(width: 65, height: 65) // Larger glow
                                .scaleEffect(animateGlow ? 1.1 : 1.0)
                                .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateGlow)
                        )
                }
            }

            Text(friend.name)
                .font(.headline)

            Spacer()

            // Display streak count next to name
            if let streak = friend.streakCount, streak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(streakColor(streak))
                    Text("\(streak)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.purple.opacity(0.08))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    func loadUserIcon(named filename: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }

    private func streakColor(_ streak: Int) -> Color {
        if streak >= 30 {
            return .red // Hot streak
        } else if streak >= 7 {
            return .orange // Good streak
        } else {
            return .gray // Default or no special color
        }
    }
}

