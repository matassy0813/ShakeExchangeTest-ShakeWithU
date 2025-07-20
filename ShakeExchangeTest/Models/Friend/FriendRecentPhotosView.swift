//
//  FriendRecentPhotosView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/23.
//

import SwiftUI

struct FriendRecentPhotosView: View {
    let recentPhotos: [AlbumPhoto]

    var body: some View {
        VStack(alignment: .leading) {
            Text("📸 Recent Shots")
                .font(.headline)
                .padding(.leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(recentPhotos.prefix(5)) { photo in
                        // ここを修正: AlbumImageView を使用して Storage から画像をロード
                        AlbumImageView(storagePath: photo.outerImage)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2) // AlbumMainView と同様にシャドウを追加
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
