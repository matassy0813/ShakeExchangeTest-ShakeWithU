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
    @State private var isPressed = false

    var body: some View {
        ZStack {
            // 背板のハイライト（ガラスっぽい反射）
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.10), .white.opacity(0.02)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 6)
                .offset(y: 2)

            HStack(spacing: 14) {
                // ✅ ローカルアイコン読込対応（元のロジックそのまま）
                ZStack {
                    if let uiImage = loadUserIcon(named: friend.icon) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 54, height: 54)
                            .clipShape(Circle())
                    } else {
                        Image(friend.icon)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 54, height: 54)
                            .clipShape(Circle())
                    }

                    // Streak ring（元の条件そのまま）
                    if let streak = friend.streakCount, streak >= 7 {
                        Circle()
                            .stroke(streakColor(streak), lineWidth: 3)
                            .frame(width: 62, height: 62)
                            .scaleEffect(animateGlow ? 1.05 : 1.0)
                            .opacity(animateGlow ? 0.8 : 0.5)
                            .animation(
                                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                value: animateGlow
                            )
                            .onAppear { animateGlow = true }
                            .overlay(
                                Circle()
                                    .fill(streakColor(streak).opacity(animateGlow ? (streak >= 30 ? 0.2 : 0.1) : 0.05))
                                    .frame(width: 70, height: 70)
                                    .scaleEffect(animateGlow ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateGlow)
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.name)
                        .font(.headline).foregroundStyle(.white)
                    if !friend.description.isEmpty {
                        Text(friend.description)
                            .lineLimit(1)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }

                Spacer()

                if let streak = friend.streakCount, streak > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(streakColor(streak))
                        Text("\(streak)")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous)) // ← ガラス
            .overlay(
                // 外周のヘアライン
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.8)
            )
            .overlay(
                // 上端の反射
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(colors: [.white.opacity(0.35), .clear],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1.2
                    )
                    .blendMode(.screen)
            )
            .frame(width: UIScreen.main.bounds.width * 0.85)
            .shadow(color: .black.opacity(0.6), radius: 14, x: 0, y: 10)  // 浮遊影
            .shadow(color: .white.opacity(0.05), radius: 2, x: 0, y: 1)   // 縁の光
            .scaleEffect(isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPressed)
            .contentShape(RoundedRectangle(cornerRadius: 18)) // カード全体をタップ可能に
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0)          // タップ時だけ軽く縮むUI演出
                    .onChanged { _ in isPressed = true }
                    .onEnded   { _ in isPressed = false }
            )
        }
    }

    // === 既存ヘルパ（変更なし） ===
    func loadUserIcon(named filename: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
    private func streakColor(_ streak: Int) -> Color {
        if streak >= 30 { return .red }
        else if streak >= 7 { return .orange }
        else { return .gray }
    }
}


