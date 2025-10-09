//
//  FriendAlbumCardView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/23.
//

import SwiftUI
import UIKit // UIImage のために必要

struct FriendAlbumCardView: View {
    let friend: Friend

    var body: some View {
        HStack {
            // ローカルアイコン読込対応 (アセットカタログ優先、次にドキュメントディレクトリ)
            if let uiImage = loadUserIcon(named: friend.icon) {
                Image(uiImage: uiImage)
                    .resizable()
                    .frame(width: 48, height: 48) // アイコンを少し大きく
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.blue.opacity(0.6), lineWidth: 1.5)) // アクセントカラーの枠
            } else {
                Image(systemName: "person.circle.fill") // fallback
                    .resizable()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .foregroundColor(.gray)
            }

            Text(friend.name)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.black) // システムデフォルト色に

            Spacer()

            Text(friend.lastInteracted)
                .font(.caption2) // 少し小さく
                .foregroundColor(.gray)
        }
        .padding(12) // パディングを調整
        .background(
            RoundedRectangle(cornerRadius: 15) // 角を丸く
                .fill(Color.white.opacity(0.9)) // 背景色を白に近く、半透明に
                .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 3) // 控えめなシャドウ
        )
        .cornerRadius(15) // 角を丸く
    }

    // MARK: - アイコン画像読み込みヘルパー
    private func loadUserIcon(named filename: String) -> UIImage? {
        // 1. アセットカタログからの読み込みを試行
        if let image = UIImage(named: filename) {
            return image
        }
        // 2. ドキュメントディレクトリからの読み込みを試行
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
}
