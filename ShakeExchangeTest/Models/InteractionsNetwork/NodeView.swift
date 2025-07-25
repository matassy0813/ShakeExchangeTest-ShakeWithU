//
//  NodeView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/25.
//

import SwiftUI

struct NodeView: View {
    let node: NetworkNode
    let position: CGPoint
    let displayNode: NetworkNode
    let iconSize: CGFloat
    let nodeSize: CGFloat
    let currentUserIconSize: CGFloat
    let currentUserNodeSize: CGFloat
    let blurRadius: (Int) -> CGFloat
    let onTap: () -> Void
    let dragGesture: (_ dragOffset: DragGesture.Value) -> Void

    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(displayNode.isCurrentUser ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                    .shadow(color: .white.opacity(0.1), radius: 4)
                    .frame(width: displayNode.isCurrentUser ? currentUserNodeSize : nodeSize,
                           height: displayNode.isCurrentUser ? currentUserNodeSize : nodeSize)
                    .overlay(
                        Circle()
                            .stroke(displayNode.isCurrentUser ? Color.blue : Color.purple.opacity(0.5), lineWidth: 2)
                    )
                    .opacity(displayNode.distance >= 5 ? 0.0 : 1.0)

                if displayNode.distance <= 1 {
                    Image(uiImage: UIImage(named: displayNode.icon) ?? UIImage(systemName: "person.circle.fill")!)
                        .resizable()
                        .scaledToFill()
                        .frame(width: displayNode.isCurrentUser ? currentUserIconSize : iconSize,
                               height: displayNode.isCurrentUser ? currentUserIconSize : iconSize)
                        .clipShape(Circle())
                        .blur(radius: blurRadius(displayNode.distance))
                }
            }

            if displayNode.distance <= 4 {
                Text(displayNode.name)
                    .font(displayNode.isCurrentUser ? .headline : (displayNode.distance == 1 ? .subheadline : .caption))
                    .fontWeight(displayNode.isCurrentUser ? .bold : .regular)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: displayNode.isCurrentUser ? currentUserNodeSize + 20 : nodeSize + 10)
                    .blur(radius: blurRadius(displayNode.distance))
                    .opacity(displayNode.distance >= 5 ? 0.0 : 1.0)
            }
        }
        .position(position)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in state = value.translation }
                .onEnded(dragGesture)
        )
        .onTapGesture {
            onTap()
        }
        .opacity(displayNode.distance >= 5 ? 0.0 : 1.0)
    }
}
