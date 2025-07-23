//
//  FriendHeaderView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/23.
//
import SwiftUI

struct FriendHeaderView: View {
    let friend: Friend

    var body: some View {
        VStack(spacing: 8) {
            if let uiImage = loadUserIcon(named: friend.icon) {
                Image(uiImage: uiImage)
                    .resizable()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .shadow(color: .white.opacity(0.2), radius: 6)
            } else {
                Image(friend.icon)
                    .resizable()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .shadow(color: .white.opacity(0.2), radius: 6)
            }

            Text(friend.name)
                .font(.title2.bold())
                .foregroundColor(.white)

            Text("@\(friend.uuid)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.top, 16)
        .background(Color.black)
    }

    private func loadUserIcon(named filename: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
}

