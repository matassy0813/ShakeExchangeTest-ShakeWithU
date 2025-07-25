//
//  ShakeTutorialView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/25.
//

import SwiftUI

struct ShakeTutorialView: View {
    let tutorialImages = ["tutorial_slide1", "tutorial_slide2", "tutorial_slide3"] // アセット名をここで列挙

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
