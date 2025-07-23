//
//  SocialNetworkView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/04.
//

import SwiftUI
import UIKit // UIImage のために必要
import Combine // Timerのために必要
import FirebaseAuth

struct SocialNetworkView: View {
    @StateObject var networkGraphManager = NetworkGraphManager()
    @ObservedObject var profileManager = ProfileManager.shared
    @ObservedObject var friendManager = FriendManager.shared
    
    

    var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    // MARK: - シミュレーションパラメータ
    let kRepulsion: CGFloat = 10000 // 斥力定数 (ノード間の反発力)
    let kAttraction: CGFloat = 0.5   // 引力定数 (エッジの引張力)
    let restLength: CGFloat = 100    // エッジの自然長
    let damping: CGFloat = 0.9       // 減衰係数 (動きを落ち着かせる)
    let timeStep: CGFloat = 0.5      // シミュレーションのタイムステップ

    // ノードの描画サイズ
    let nodeSize: CGFloat = 60
    let currentUserNodeSize: CGFloat = 80
    let iconSize: CGFloat = 40
    let currentUserIconSize: CGFloat = 60

    @State private var viewSize: CGSize = .zero // ビュー全体のサイズを保持
    @State private var simulationTimer: Timer? // シミュレーションを駆動するタイマー
    @State private var isSimulationRunning: Bool = false // シミュレーションが実行中か

    // ドラッグジェスチャーの状態
    @GestureState private var dragOffset: CGSize = .zero
    @State private var activeNodeID: String? = nil

    // MARK: - ユーザーアイコン読み込みヘルパー
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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()  // 背景色

            if networkGraphManager.isLoading {
                ProgressView("Building Network...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .foregroundColor(.white)
            } else if networkGraphManager.errorMessage != nil {
                ContentUnavailableView(
                    "Error Loading Network",
                    systemImage: "exclamationmark.triangle.fill",
                    description: Text(networkGraphManager.errorMessage ?? "An unknown error occurred.")
                )
                .foregroundColor(.white)
            }
            else if networkGraphManager.socialNetworkGraph.nodes.isEmpty {
                ContentUnavailableView(
                    "No Network Yet",
                    systemImage: "network",
                    description: Text("Shake your phone with someone to start building your network!")
                        .foregroundColor(.white)
                )
            } else {
                GeometryReader { geometry in
                    // ビューサイズをキャプチャ
                    Color.clear
                        .onAppear {
                            viewSize = geometry.size
                            // サーバーから初期位置が提供されるため、ここではランダム初期化は不要
                            // ただし、画面サイズに合わせてノード位置をスケーリングする必要がある
                            adjustNodePositionsToFitView(graph: networkGraphManager.socialNetworkGraph, viewSize: geometry.size)
                            startSimulation()
                        }
                        .onChange(of: geometry.size) { newSize in
                            viewSize = newSize
                            // サイズ変更時にノード位置を調整
                            adjustNodePositionsToFitView(graph: networkGraphManager.socialNetworkGraph, viewSize: newSize)
                        }
                        .onChange(of: networkGraphManager.socialNetworkGraph.nodes.count) { _ in
                            // グラフのノード数に変更があった場合、シミュレーションを再開 (または初期化)
                            adjustNodePositionsToFitView(graph: networkGraphManager.socialNetworkGraph, viewSize: geometry.size)
                            startSimulation()
                        }
                        .onChange(of: networkGraphManager.socialNetworkGraph.nodes) { newNodes in
                             // nodes辞書全体が変更された場合にシミュレーションを再開
                             // (例: サーバーから新しいグラフがロードされた場合など)
                             if !newNodes.isEmpty {
                                 adjustNodePositionsToFitView(graph: networkGraphManager.socialNetworkGraph, viewSize: geometry.size)
                                 startSimulation()
                             }
                         }

                    // エッジの描画
                    Canvas { context, size in
                        for (sourceId, targets) in networkGraphManager.socialNetworkGraph.adjacencyList {
                            guard let sourceNode = networkGraphManager.socialNetworkGraph.nodes[sourceId] else { continue }
                            let sourcePosition = sourceNode.position
                            
                            for targetId in targets {
                                // 重複描画を防ぐため、sourceId < targetId の場合のみ描画
                                if sourceId < targetId {
                                    guard let targetNode = networkGraphManager.socialNetworkGraph.nodes[targetId] else { continue }
                                    let targetPosition = targetNode.position
                                    
                                    var path = Path()
                                    path.move(to: sourcePosition)
                                    path.addLine(to: targetPosition)
                                    
                                    context.stroke(path, with: .color(Color.white.opacity(0.1)), lineWidth: 0.5)
                                }
                            }
                        }
                    }

                    // ノードの描画
                    ForEach(networkGraphManager.socialNetworkGraph.nodes.values.sorted(by: { $0.distance < $1.distance })) { node in
                        // ドラッグ中のノードの位置を調整
                        let currentPosition = (activeNodeID == node.id && node.isDragging) ?
                            CGPoint(x: node.position.x + dragOffset.width, y: node.position.y + dragOffset.height) :
                            node.position
                        
                        // ここでノードの `name` と `icon` を `ProfileManager` と `FriendManager` から補完
                        let displayNode: NetworkNode = {
                            var tempNode = node
                            if node.isCurrentUser {
                                tempNode.name = profileManager.currentUser.name
                                tempNode.icon = profileManager.currentUser.icon
                            } else if let friend = friendManager.friends.first(where: { $0.uuid == node.id }) {
                                tempNode.name = friend.name
                                tempNode.icon = friend.icon
                            } else {
                                // 友達でも自分でもない場合（2次以降のつながり）は、IDを名前にフォールバック
                                // アイコンは不明とする
                                if tempNode.name.isEmpty {
                                    tempNode.name = "User \(String(node.id.suffix(4)))" // IDの一部を表示
                                }
                                if tempNode.icon.isEmpty {
                                    tempNode.icon = "person.circle.fill" // システムアイコン名
                                }
                            }
                            return tempNode
                        }()

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
                                    .opacity(displayNode.distance >= 5 ? 0.0 : 1.0) // 距離5以上は円も非表示 (点として表示)

                                // アイコンの表示制御: 距離1まで（直接の友達）はアイコン表示
                                if displayNode.distance <= 1 {
                                    if let uiImage = loadUserIcon(named: displayNode.icon) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: displayNode.isCurrentUser ? currentUserIconSize : iconSize,
                                                   height: displayNode.isCurrentUser ? currentUserIconSize : iconSize)
                                            .clipShape(Circle())
                                            .blur(radius: blurRadius(for: displayNode.distance)) // 距離に応じたぼかし
                                    } else {
                                        Image(systemName: "person.circle.fill") // フォールバックアイコン
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: displayNode.isCurrentUser ? currentUserIconSize : iconSize,
                                                   height: displayNode.isCurrentUser ? currentUserIconSize : iconSize)
                                            .foregroundColor(.gray)
                                            .blur(radius: blurRadius(for: displayNode.distance)) // 距離に応じたぼかし
                                    }
                                } else {
                                    // 距離2-4はアイコン非表示（名前のみ）
                                    // 距離5以上はアイコンも名前も非表示なので、ここでは何もしない
                                }
                            }
                            // 名前表示の制御: 距離4以下は名前表示
                            if displayNode.distance <= 4 {
                                Text(displayNode.name)
                                    .font(displayNode.isCurrentUser ? .headline : (displayNode.distance == 1 ? .subheadline : .caption))
                                    .fontWeight(displayNode.isCurrentUser ? .bold : .regular)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(width: displayNode.isCurrentUser ? currentUserNodeSize + 20 : nodeSize + 10) // 名前がはみ出さないように幅を調整
                                    .blur(radius: blurRadius(for: displayNode.distance)) // 距離に応じたぼかし
                                    .opacity(displayNode.distance >= 5 ? 0.0 : 1.0) // 距離5以上の場合は名前を完全に非表示
                            }
                        }
                        .position(currentPosition)
                        .gesture(
                            DragGesture()
                                .updating($dragOffset) { value, state, _ in
                                    state = value.translation
                                }
                                .onChanged { value in
                                    // ドラッグ開始時にノードを特定
                                    if activeNodeID == nil {
                                        activeNodeID = node.id
                                        networkGraphManager.socialNetworkGraph.nodes[node.id]?.isDragging = true
                                    }
                                }
                                .onEnded { value in
                                    // ドラッグ終了時にノードの位置を更新し、ドラッグ状態を解除
                                    networkGraphManager.socialNetworkGraph.nodes[node.id]?.position = CGPoint(
                                        x: node.position.x + value.translation.width,
                                        y: node.position.y + value.translation.height
                                    )
                                    networkGraphManager.socialNetworkGraph.nodes[node.id]?.isDragging = false
                                    activeNodeID = nil
                                    // ドラッグ終了後もシミュレーションを継続
                                    startSimulation()
                                }
                        )
                        .onTapGesture {
                            handleNodeTap(node: displayNode) // 補完されたノード情報を使用
                        }
                        .opacity(displayNode.distance >= 5 ? 0.0 : 1.0) // 距離5以上のノード全体を非表示
                    }
                }
            }
        }
        .navigationTitle("Network Graph")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                print("[SocialNetworkView] 🔄 ネットワークグラフの取得を開始します")
                await networkGraphManager.loadNetworkGraph(for: currentUserId)
            }
        }
        .onDisappear {
            stopSimulation() // ビューが非表示になったらシミュレーションを停止
        }
    }

    // MARK: - ノード位置調整 (サーバーからの位置をビューサイズにフィットさせる)
    private func adjustNodePositionsToFitView(graph: SocialNetworkGraph, viewSize: CGSize) {
        guard viewSize != .zero && !graph.nodes.isEmpty else { return }

        // 現在のノードの最大/最小 x, y を取得
        var minX: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = -.greatestFiniteMagnitude
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxY: CGFloat = -.greatestFiniteMagnitude

        for node in graph.nodes.values {
            minX = min(minX, node.position.x)
            maxX = max(maxX, node.position.x)
            minY = min(minY, node.position.y)
            maxY = max(maxY, node.position.y)
        }

        let currentGraphWidth = maxX - minX
        let currentGraphHeight = maxY - minY

        // スケーリングファクターを計算 (パディングを考慮)
        let padding: CGFloat = 50 // 適度なパディング
        let scaleX = (viewSize.width - padding * 2) / max(currentGraphWidth, 1.0)
        let scaleY = (viewSize.height - padding * 2) / max(currentGraphHeight, 1.0)
        let scale = min(scaleX, scaleY) // 縦横比を維持するために小さい方を採用

        // 全体を中央に配置するためのオフセット
        let offsetX = (viewSize.width / 2) - ((minX + maxX) / 2) * scale
        let offsetY = (viewSize.height / 2) - ((minY + maxY) / 2) * scale

        var tempNodes = graph.nodes
        for id in tempNodes.keys {
            if var node = tempNodes[id] {
                node.position.x = node.position.x * scale + offsetX
                node.position.y = node.position.y * scale + offsetY
                tempNodes[id] = node
            }
        }
        networkGraphManager.socialNetworkGraph.nodes = tempNodes
        print("[SocialNetworkView] 🌐 ノード位置をビューサイズに合わせて調整しました。")
    }

    // MARK: - シミュレーションの開始/停止
    private func startSimulation() {
        stopSimulation() // 既存のタイマーがあれば停止
        isSimulationRunning = true
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            self.updateSimulation()
        }
        print("[SocialNetworkView] ⚙️ シミュレーションを開始しました。")
    }

    private func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        isSimulationRunning = false
        print("[SocialNetworkView] 🛑 シミュレーションを停止しました。")
    }

    // MARK: - シミュレーションの更新ロジック
    private func updateSimulation() {
        guard !networkGraphManager.socialNetworkGraph.nodes.isEmpty else {
            stopSimulation()
            return
        }

        var tempNodes = networkGraphManager.socialNetworkGraph.nodes

        // 1. 全てのノードの力をリセット
        for id in tempNodes.keys {
            tempNodes[id]?.force = .zero
        }

        // 2. 斥力 (Repulsion Force - Coulomb's Law)
        let nodeIDs = Array(tempNodes.keys)
        for i in 0..<nodeIDs.count {
            for j in (i + 1)..<nodeIDs.count {
                let node1ID = nodeIDs[i]
                let node2ID = nodeIDs[j]

                guard let node1 = tempNodes[node1ID],
                      let node2 = tempNodes[node2ID],
                      !node1.isDragging, !node2.isDragging else { continue }

                let dx = node2.position.x - node1.position.x
                let dy = node2.position.y - node1.position.y
                let distance = max(sqrt(dx*dx + dy*dy), 1.0)

                let forceMagnitude = kRepulsion / (distance * distance)
                let forceX = forceMagnitude * dx / distance
                let forceY = forceMagnitude * dy / distance

                tempNodes[node1ID]?.force.dx -= forceX
                tempNodes[node1ID]?.force.dy -= forceY
                tempNodes[node2ID]?.force.dx += forceX
                tempNodes[node2ID]?.force.dy += forceY
            }
        }

        // 3. 引力 (Attraction Force - Hooke's Law)
        for (sourceId, targets) in networkGraphManager.socialNetworkGraph.adjacencyList {
            guard let sourceNode = tempNodes[sourceId], !sourceNode.isDragging else { continue }

            for targetId in targets {
                guard let targetNode = tempNodes[targetId], !targetNode.isDragging else { continue }

                let dx = targetNode.position.x - sourceNode.position.x
                let dy = targetNode.position.y - sourceNode.position.y
                let distance = max(sqrt(dx*dx + dy*dy), 1.0)

                let forceMagnitude = kAttraction * (distance - restLength)
                let forceX = forceMagnitude * dx / distance
                let forceY = forceMagnitude * dy / distance

                tempNodes[sourceId]?.force.dx += forceX
                tempNodes[sourceId]?.force.dy += forceY
                tempNodes[targetId]?.force.dx -= forceX
                tempNodes[targetId]?.force.dy -= forceY
            }
        }
        
        // 4. 重力 (中心への引き寄せ)
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let gravityStrength: CGFloat = 0.005
        
        for id in tempNodes.keys {
            guard var node = tempNodes[id], !node.isDragging else { continue }
            
            let dx = center.x - node.position.x
            let dy = center.y - node.position.y
            
            node.force.dx += dx * gravityStrength
            node.force.dy += dy * gravityStrength
            tempNodes[id] = node
        }

        // 5. 速度と位置の更新 (Euler Integration) と減衰
        for id in tempNodes.keys {
            guard var node = tempNodes[id], !node.isDragging else { continue }

            let effectiveDamping = (networkGraphManager.socialNetworkGraph.nodes[id]?.distance ?? 0) <= 3 ? damping : 0.98
            let effectiveTimeStep = (networkGraphManager.socialNetworkGraph.nodes[id]?.distance ?? 0) <= 3 ? timeStep : 0.1

            node.velocity.dx = (node.velocity.dx + node.force.dx * effectiveTimeStep) * effectiveDamping
            node.velocity.dy = (node.velocity.dy + node.force.dy * effectiveTimeStep) * effectiveDamping

            node.position.x += node.velocity.dx * effectiveTimeStep
            node.position.y += node.velocity.dy * effectiveTimeStep

            // 画面境界内にとどめる
            node.position.x = max(nodeSize / 2, min(node.position.x, viewSize.width - nodeSize / 2))
            node.position.y = max(nodeSize / 2, min(node.position.y, viewSize.height - nodeSize / 2))
            
            tempNodes[id] = node
        }
        
        networkGraphManager.socialNetworkGraph.nodes = tempNodes
    }

    // MARK: - 距離に応じたぼかしの計算
    private func blurRadius(for distance: Int) -> CGFloat {
        switch distance {
        case 0, 1: return 0
        case 2: return 2
        case 3: return 5
        case _ where distance >= 4: return 10
        default: return 0
        }
    }

    // MARK: - ノードタップ処理
    private func handleNodeTap(node: NetworkNode) {
        if node.isCurrentUser {
            print("👤 Current user tapped: \(node.name)")
        } else if node.distance == 1 {
            print("👥 Direct friend tapped: \(node.name)")
            if let friend = friendManager.friends.first(where: { $0.uuid == node.id }) {
                print("Navigating to \(friend.name)'s profile. (Placeholder for actual navigation)")
            }
        } else if node.distance >= 2 && node.distance <= 4 {
            print("🚫 Friend at distance \(node.distance) tapped. Profile not viewable (name only).")
        } else if node.distance >= 5 {
            print("🚫 Friend at distance \(node.distance) tapped. Information hidden.")
        }
    }
}
