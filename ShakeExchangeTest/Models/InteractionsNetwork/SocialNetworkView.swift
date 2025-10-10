//
//  SocialNetworkView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/04.
//

import SwiftUI
import UIKit
import Combine
import FirebaseAuth

struct SocialNetworkView: View {
    @StateObject var networkGraphManager = NetworkGraphManager() //
    @ObservedObject var profileManager = ProfileManager.shared //
    @ObservedObject var friendManager = FriendManager.shared //
    
    @StateObject private var adManager = InterstitialAdManager() //
    @Environment(\.presentationMode) var presentationMode //
    @State private var selectedNodeForMeet: NetworkNode? = nil
    
    @State private var lastUIFlush: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    private let uiFlushInterval: CFTimeInterval = 0.10
    
    var currentUserId: String { //
        Auth.auth().currentUser?.uid ?? "" //
    }

    // MARK: - シミュレーションパラメータ
    let kRepulsion: CGFloat = 10000 // 斥力定数 (ノード間の反発力)
    let kAttraction: CGFloat = 0.5   // 引力定数 (エッジの引張力)
    let restLength: CGFloat = 100    // エッジの自然長
    let damping: CGFloat = 0.9       // 減衰係数 (動きを落ち着かせる)
    let timeStep: CGFloat = 0.5      // シミュレーションのタイムステップ

    // ノードの描画サイズ
    let nodeSize: CGFloat = 60 //
    let currentUserNodeSize: CGFloat = 80 //
    let iconSize: CGFloat = 40 //
    let currentUserIconSize: CGFloat = 60 //
    // MARK: - 【追加】シミュレーション停止判定用プロパティ
    private let movementThreshold: CGFloat = 0.5 // ノードの平均移動量がこの値以下になったら停止
    private let stabilizationDelay: Int = 30 // 閾値以下が連続したフレーム数 (約1秒)
    private var stabilizationCount: Int = 0

    @State private var viewSize: CGSize = .zero // ビュー全体のサイズを保持
    @State private var simulationTimer: Timer? // シミュレーションを駆動するタイマー
    @State private var isSimulationRunning: Bool = false // シミュレーションが実行中か

    // ドラッグジェスチャーの状態
    @GestureState private var dragOffset: CGSize = .zero //
    @State private var activeNodeID: String? = nil //

    // MARK: - ユーザーアイコン読み込みヘルパー
    private func loadUserIcon(named filename: String) -> UIImage? { //
        // 1. アセットカタログからの読み込みを試行
        if let image = UIImage(named: filename) { //
            return image //
        }
        // 2. ドキュメントディレクトリからの読み込みを試行
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] //
            .appendingPathComponent(filename) //
        return UIImage(contentsOfFile: url.path) //
    }

    var body: some View { //
        ZStack { //
            Color.black.ignoresSafeArea()  // 背景色

            // SocialNetworkView.swift の body 内、読み込み中の表示
            if networkGraphManager.isLoading {
                VStack(spacing: 16) {
                    SpinnerView()  // ← ここだけ差し替え
                    Text("Building Network...")
                        .font(.title2).bold()
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.top, 40)
            } else if networkGraphManager.errorMessage != nil { //
                ContentUnavailableView( //
                    "Error Loading Network", //
                    systemImage: "exclamationmark.triangle.fill", //
                    description: Text(networkGraphManager.errorMessage ?? "An unknown error occurred.") //
                )
                .foregroundColor(.white) //
            }
            else if networkGraphManager.socialNetworkGraph.nodes.isEmpty { //
                ContentUnavailableView( //
                    "No Network Yet", //
                    systemImage: "network", //
                    description: Text("Shake your phone with someone to start building your network!") //
                        .foregroundColor(.white) //
                )
            } else { //
                GeometryReader { geometry in //
                    // ビューサイズをキャプチャ
                    Color.clear //
                        .onAppear { //
                            viewSize = geometry.size //
                            adjustNodePositionsToFitView(graph: networkGraphManager.socialNetworkGraph, viewSize: geometry.size) //
                            startSimulation() //
                        }
                        .onChange(of: geometry.size) { newSize in //
                            viewSize = newSize //
                            adjustNodePositionsToFitView(graph: networkGraphManager.socialNetworkGraph, viewSize: newSize) //
                        }
                        .onChange(of: networkGraphManager.socialNetworkGraph.nodes.count) { _ in //
                            adjustNodePositionsToFitView(graph: networkGraphManager.socialNetworkGraph, viewSize: geometry.size) //
                            startSimulation() //
                        }
                        .onChange(of: networkGraphManager.socialNetworkGraph.nodes) { newNodes in //
                             if !newNodes.isEmpty { //
                                 adjustNodePositionsToFitView(graph: networkGraphManager.socialNetworkGraph, viewSize: geometry.size) //
                                 startSimulation() //
                             }
                         }

                    // エッジの描画
                    Canvas { context, size in //
                        for (sourceId, targets) in networkGraphManager.socialNetworkGraph.adjacencyList { //
                            guard let sourceNode = networkGraphManager.socialNetworkGraph.nodes[sourceId] else { continue } //
                            let sourcePosition = sourceNode.position //
                            
                            for targetId in targets { //
                                if sourceId < targetId { //
                                    guard let targetNode = networkGraphManager.socialNetworkGraph.nodes[targetId] else { continue } //
                                    let targetPosition = targetNode.position //
                                    
                                    var path = Path() //
                                    path.move(to: sourcePosition) //
                                    path.addLine(to: targetPosition) //
                                    
                                    context.stroke(path, with: .color(Color.white.opacity(0.8)), lineWidth: 0.5) //
                                }
                            }
                        }
                    }
                    .allowsHitTesting(false)
                    // ノードの描画
                    ForEach(networkGraphManager.socialNetworkGraph.nodes.values.sorted(by: { $0.distance < $1.distance })) { node in //
                        nodeView(for: node) //
                    }
                }
                .compositingGroup()
                .drawingGroup()
            }
        }
        .compositingGroup()
        .drawingGroup()
        .sheet(item: $selectedNodeForMeet) { node in
            MeetMessageView(targetNode: node, onSend: { message in
                networkGraphManager.sendMeet(to: node.id, message: message)
            })
        }
        .navigationTitle("Network Graph") //
        .navigationBarTitleDisplayMode(.inline) //
        .onAppear { //
            func startNetworkLoadAndCheckSession() { //
                Task { //
                    print("[SocialNetworkView] 🔄 ネットワークグラフの取得を開始します") //
                    await networkGraphManager.loadNetworkGraph(for: currentUserId) //
                    // プロフィールロード後、セッション有効期限をチェック
                    print("[SocialNetworkView] 🔄 セッション有効期限のチェックを開始します。") //
                    await AuthManager.shared.checkSessionValidity() //
                }
            }

            if adManager.isAdLoaded { //
                if let rootVC = UIApplication.shared.windows.first?.rootViewController { //
                    adManager.showAd(from: rootVC, onPresented: { //
                        print("📣 Interstitial Ad presented") //
                    }, onDismissed: { //
                        startNetworkLoadAndCheckSession() // 広告表示後にネットワークロードとセッションチェック
                    })
                } else {
                    startNetworkLoadAndCheckSession() //
                }
            } else { //
                print("⌛ Ad not yet loaded. Waiting...") //
                adManager.loadAd() // 明示的にロード（念のため）

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { //
                    if adManager.isAdLoaded, //
                       let rootVC = UIApplication.shared.windows.first?.rootViewController { //
                        adManager.showAd(from: rootVC, onPresented: { //
                            print("📣 Interstitial Ad presented (delayed)") //
                        }, onDismissed: { //
                            startNetworkLoadAndCheckSession() // 広告表示後にネットワークロードとセッションチェック
                        })
                    } else { //
                        print("⚠️ Ad still not loaded. Proceeding without ad.") //
                        startNetworkLoadAndCheckSession() //
                    }
                }
            }
        }
        .onDisappear { //
            stopSimulation() // ビューが非表示になったらシミュレーションを停止
        }
    }
    
    @ViewBuilder
    private func nodeView(for node: NetworkNode) -> some View { //
        let currentPosition = (activeNodeID == node.id && node.isDragging) ? //
            CGPoint(x: node.position.x + dragOffset.width, y: node.position.y + dragOffset.height) : //
            node.position //

        let displayNode: NetworkNode = { //
            var tempNode = node //
            if node.isCurrentUser { //
                tempNode.name = profileManager.currentUser.name //
                tempNode.icon = profileManager.currentUser.icon //
            } else if let friend = friendManager.friends.first(where: { $0.uuid == node.id }) { //
                tempNode.name = friend.name //
                tempNode.icon = friend.icon //
            } else { //
                if tempNode.name.isEmpty { //
                    tempNode.name = "User \(String(node.id.suffix(4)))" //
                }
                if tempNode.icon.isEmpty { //
                    tempNode.icon = "person.circle.fill" //
                }
            }
            return tempNode //
        }()

        VStack { //
            ZStack { //
                if displayNode.distance >= 5 {
                    // 点として描画
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 6, height: 6)
                } else {
                    Circle() //
                        .fill(displayNode.isCurrentUser ? Color.white.opacity(0.08) : Color.white.opacity(0.03)) //
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5)) //
                        .shadow(color: .white.opacity(0.1), radius: 4) //
                        .frame(width: displayNode.isCurrentUser ? currentUserNodeSize : nodeSize, //
                               height: displayNode.isCurrentUser ? currentUserNodeSize : nodeSize) //
                        .overlay( //
                            Circle() //
                                .stroke(displayNode.isCurrentUser ? Color.blue : Color.purple.opacity(0.5), lineWidth: 2) //
                        )
                        .opacity(displayNode.distance >= 5 ? 0.0 : 1.0) //
                    
                    if displayNode.distance <= 1 { //
                        if let uiImage = loadUserIcon(named: displayNode.icon) { //
                            Image(uiImage: uiImage) //
                                .resizable() //
                                .scaledToFill() //
                                .frame(width: displayNode.isCurrentUser ? currentUserIconSize : iconSize, //
                                       height: displayNode.isCurrentUser ? currentUserIconSize : iconSize) //
                                .clipShape(Circle()) //
                                .blur(radius: blurRadius(for: displayNode.distance)) //
                        } else { //
                            Image(systemName: "person.circle.fill") //
                                .resizable() //
                                .scaledToFit() //
                                .frame(width: displayNode.isCurrentUser ? currentUserIconSize : iconSize, //
                                       height: displayNode.isCurrentUser ? currentUserIconSize : iconSize) //
                                .foregroundColor(.gray) //
                                .blur(radius: blurRadius(for: displayNode.distance)) //
                        }
                    }
                }
            }

            if displayNode.distance <= 4 { //
                Text(displayNode.name) //
                    .font(displayNode.isCurrentUser ? .headline : (displayNode.distance == 1 ? .subheadline : .caption)) //
                    .fontWeight(displayNode.isCurrentUser ? .bold : .regular) //
                    .foregroundColor(.white) //
                    .lineLimit(1) //
                    .minimumScaleFactor(0.7) //
                    .frame(width: displayNode.isCurrentUser ? currentUserNodeSize + 20 : nodeSize + 10) //
                    .blur(radius: blurRadius(for: displayNode.distance)) //
                    .opacity(displayNode.distance >= 5 ? 0.0 : 1.0) //
            }
        }
        .position(currentPosition) //
        .gesture( //
            DragGesture() //
                .updating($dragOffset) { value, state, _ in //
                    state = value.translation //
                }
                .onChanged { value in //
                    if activeNodeID == nil { //
                        activeNodeID = node.id //
                        networkGraphManager.socialNetworkGraph.nodes[node.id]?.isDragging = true //
                    }
                }
                .onEnded { value in //
                    networkGraphManager.socialNetworkGraph.nodes[node.id]?.position = CGPoint( //
                        x: node.position.x + value.translation.width, //
                        y: node.position.y + value.translation.height //
                    )
                    networkGraphManager.socialNetworkGraph.nodes[node.id]?.isDragging = false //
                    activeNodeID = nil //
                    startSimulation() //
                }
        )
        .transaction { txn in
            // 物理シミュが毎フレーム座標を更新する部分だけは"瞬時描画"に
            txn.animation = nil
        }
        .onTapGesture { //
            handleNodeTap(node: displayNode) //
        }
        .transaction { $0.animation = nil }
        /*.opacity(displayNode.distance >= 5 ? 0.0 : 1.0)*/ //
    }

    // MARK: - ノード位置調整 (サーバーからの位置をビューサイズにフィットさせる)
    private func adjustNodePositionsToFitView(graph: SocialNetworkGraph, viewSize: CGSize) { //
        guard viewSize != .zero && !graph.nodes.isEmpty else { return } //

        var minX: CGFloat = .greatestFiniteMagnitude //
        var maxX: CGFloat = -.greatestFiniteMagnitude //
        var minY: CGFloat = .greatestFiniteMagnitude //
        var maxY: CGFloat = -.greatestFiniteMagnitude //

        for node in graph.nodes.values { //
            minX = min(minX, node.position.x) //
            maxX = max(maxX, node.position.x) //
            minY = min(minY, node.position.y) //
            maxY = max(maxY, node.position.y) //
        }

        let currentGraphWidth = maxX - minX //
        let currentGraphHeight = maxY - minY //

        let padding: CGFloat = 50 // 適度なパディング
        let scaleX = (viewSize.width - padding * 2) / max(currentGraphWidth, 1.0) //
        let scaleY = (viewSize.height - padding * 2) / max(currentGraphHeight, 1.0) //
        let scale = min(scaleX, scaleY) // 縦横比を維持するために小さい方を採用

        let offsetX = (viewSize.width / 2) - ((minX + maxX) / 2) * scale //
        let offsetY = (viewSize.height / 2) - ((minY + maxY) / 2) * scale //

        var tempNodes = graph.nodes //
        for id in tempNodes.keys { //
            if var node = tempNodes[id] { //
                node.position.x = node.position.x * scale + offsetX //
                node.position.y = node.position.y * scale + offsetY //
                node.velocity = .zero // 速度をゼロにリセット
                tempNodes[id] = node //
            }
        }
        networkGraphManager.socialNetworkGraph.nodes = tempNodes //
        print("[SocialNetworkView] 🌐 ノード位置をビューサイズに合わせて調整しました。") //
    }

    // MARK: - シミュレーションの開始/停止
    private func startSimulation() { //
        stopSimulation() // 既存のタイマーがあれば停止
        isSimulationRunning = true //
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in //
            self.updateSimulation() //
        }
        print("[SocialNetworkView] ⚙️ シミュレーションを開始しました。") //
    }

    private func stopSimulation() { //
        simulationTimer?.invalidate() //
        simulationTimer = nil //
        isSimulationRunning = false //
        print("[SocialNetworkView] 🛑 シミュレーションを停止しました。") //
    }

    // MARK: - シミュレーションの更新ロジック
    private func updateSimulation() { //
        guard !networkGraphManager.socialNetworkGraph.nodes.isEmpty else { //
            stopSimulation() //
            return //
        }

        var tempNodes = networkGraphManager.socialNetworkGraph.nodes //

        // 1. 全てのノードの力をリセット
        for id in tempNodes.keys { //
            tempNodes[id]?.force = .zero //
        }

        // 2. 斥力 (Repulsion Force - Coulomb's Law)
        let nodeIDs = Array(tempNodes.keys) //
        for i in 0..<nodeIDs.count { //
            for j in (i + 1)..<nodeIDs.count { //
                let node1ID = nodeIDs[i] //
                let node2ID = nodeIDs[j] //

                guard let node1 = tempNodes[node1ID], //
                      let node2 = tempNodes[node2ID], //
                      !node1.isDragging, !node2.isDragging else { continue } //

                let dx = node2.position.x - node1.position.x //
                let dy = node2.position.y - node1.position.y //
                let distance = max(sqrt(dx*dx + dy*dy), 1.0) //

                let forceMagnitude = kRepulsion / (distance * distance) //
                let forceX = forceMagnitude * dx / distance //
                let forceY = forceMagnitude * dy / distance //

                tempNodes[node1ID]?.force.dx -= forceX //
                tempNodes[node1ID]?.force.dy -= forceY //
                tempNodes[node2ID]?.force.dx += forceX //
                tempNodes[node2ID]?.force.dy += forceY //
            }
        }

        // 3. 引力 (Attraction Force - Hooke's Law)
        for (sourceId, targets) in networkGraphManager.socialNetworkGraph.adjacencyList { //
            guard let sourceNode = tempNodes[sourceId], !sourceNode.isDragging else { continue } //

            for targetId in targets { //
                guard let targetNode = tempNodes[targetId], !targetNode.isDragging else { continue } //

                let dx = targetNode.position.x - sourceNode.position.x //
                let dy = targetNode.position.y - sourceNode.position.y //
                let distance = max(sqrt(dx*dx + dy*dy), 1.0) //

                let forceMagnitude = kAttraction * (distance - restLength) //
                let forceX = forceMagnitude * dx / distance //
                let forceY = forceMagnitude * dy / distance //

                tempNodes[sourceId]?.force.dx += forceX //
                tempNodes[sourceId]?.force.dy += forceY //
                tempNodes[targetId]?.force.dx -= forceX //
                tempNodes[targetId]?.force.dy -= forceY //
            }
        }
        
        // 4. 重力 (中心への引き寄せ)
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2) //
        let gravityStrength: CGFloat = 0.005 //
        
        for id in tempNodes.keys { //
            guard var node = tempNodes[id], !node.isDragging else { continue } //
            
            let dx = center.x - node.position.x //
            let dy = center.y - node.position.y //
            
            node.force.dx += dx * gravityStrength //
            node.force.dy += dy * gravityStrength //
            tempNodes[id] = node //
        }

        // 5. 速度と位置の更新 (Euler Integration) と減衰
        for id in tempNodes.keys { //
            guard var node = tempNodes[id], !node.isDragging else { continue } //

            let effectiveDamping = (networkGraphManager.socialNetworkGraph.nodes[id]?.distance ?? 0) <= 3 ? damping : 0.98 //
            let effectiveTimeStep = (networkGraphManager.socialNetworkGraph.nodes[id]?.distance ?? 0) <= 3 ? timeStep : 0.1 //
            
            // 5. 速度と位置の更新 (Euler Integration) と減衰
            var totalMovement: CGFloat = 0 // 【追加】移動量合計のトラッキング
            let nodesCount = CGFloat(tempNodes.keys.count)

            node.velocity.dx = (node.velocity.dx + node.force.dx * effectiveTimeStep) * effectiveDamping //
            node.velocity.dy = (node.velocity.dy + node.force.dy * effectiveTimeStep) * effectiveDamping //

            node.position.x += node.velocity.dx * effectiveTimeStep //
            node.position.y += node.velocity.dy * effectiveTimeStep //

            // 画面境界内にとどめる
            node.position.x = max(nodeSize / 2, min(node.position.x, viewSize.width - nodeSize / 2)) //
            node.position.y = max(nodeSize / 2, min(node.position.y, viewSize.height - nodeSize / 2)) //
            
            tempNodes[id] = node //
        }
        
        networkGraphManager.socialNetworkGraph.nodes = tempNodes //
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastUIFlush >= uiFlushInterval {
            lastUIFlush = now
            // 同一値を"再代入"して @Published を明示発火（頻度だけ間引く）
            networkGraphManager.socialNetworkGraph = networkGraphManager.socialNetworkGraph
        }
        
    }

    // MARK: - 距離に応じたぼかしの計算
    private func blurRadius(for distance: Int) -> CGFloat { //
        switch distance { //
        case 0, 1: return 0 //
        case 2: return 2 //
        case 3: return 5 //
        case _ where distance >= 4: return 10 //
        default: return 0 //
        }
    }

    // MARK: - ノードタップ処理
    private func handleNodeTap(node: NetworkNode) {
        if node.isCurrentUser {
            print("👤 Current user tapped: \(node.name)")
        } else if node.distance <= 4 {
            selectedNodeForMeet = node
        } else {
            print("🚫 Node too far for meet: \(node.name)")
        }
    }
    
    /// 合成やOSに左右されない純SwiftUIスピナー
    private struct SpinnerView: View {
        @State private var rotate = false

        var body: some View {
            Circle()
                .trim(from: 0.08, to: 0.92) // 円弧
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            .white.opacity(0.95), .white.opacity(0.25), .white.opacity(0.05), .white.opacity(0.25), .white.opacity(0.95)
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: rotate)
                .onAppear { rotate = true }
                .accessibilityLabel("Loading")
        }
    }

}
