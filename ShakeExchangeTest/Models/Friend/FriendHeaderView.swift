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
            } else {
                Image(friend.icon)
                    .resizable()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            }

            Text(friend.name)
                .font(.title2)
                .bold()

            Text("@\(friend.uuid)")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    private func loadUserIcon(named filename: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
}

