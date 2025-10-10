//
//  ShakeTutorialView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/25.
//

import SwiftUI

struct ShakeTutorialView: View {
    let tutorialImages = ["how_to_1", "how_to_2", "how_to_3", "how_to_4", "how_to_5", "how_to_6", "how_to_7", "how_to_8", "how_to_9", "how_to_10", "how_to_11", "how_to_12", "how_to_13", "how_to_14", "how_to_15", "how_to_16", "how_to_17", "how_to_18", "how_to_19"] // アセット名をここで列挙

    @Environment(\.presentationMode) var presentationMode
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(tutorialImages.indices, id: \.self) { index in
                    VStack {
                        Image(tutorialImages[index])
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .padding()

                        Text("ステップ \(index + 1)")
                            .font(.headline)
                            .padding(.top)

                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            .background(Color.black.opacity(0.95))
            .ignoresSafeArea()

            // 下部に「閉じる」ボタン
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("チュートリアルを閉じる")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding()
            }
            .background(Color.black)
        }
    }
}
