//
//  NetworkModels.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/03.
//

import Foundation
import SwiftUI // Color, UIImage のために必要

import CoreGraphics
// MARK: - ネットワークグラフのノード (ユーザー) を表す構造体
struct NetworkNode: Identifiable, Hashable {
    let id: String // UUIDをIDとして使用
    var name: String // var に変更して後で補完可能にする
    var icon: String // var に変更して後で補完可能にする
    var distance: Int = -1 // 基準ノードからの最短距離 (-1は未到達)
    var isCurrentUser: Bool = false // 現在のユーザーであるか
    
    // MARK: - ばねモデル用プロパティ
    var position: CGPoint // 初期値を指定しないことで、初期化時に必ず設定されるようにする
    var velocity: CGVector = .zero // ノードの現在の速度
    var force: CGVector = .zero // ノードに作用している現在の力
    var isDragging: Bool = false // ドラッグ中かどうか

    // Hashable準拠のためのプロパティ
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: NetworkNode, rhs: NetworkNode) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ネットワークグラフのエッジ (友達関係) を表す構造体
// 双方向の友達関係のみをエッジとする
struct NetworkEdge: Identifiable, Hashable {
    let id = UUID() // エッジ自体のユニークID
    let sourceNodeId: String // 接続元ノードのUUID
    let targetNodeId: String // 接続先ノードのUUID
    
    // Hashable準拠のためのプロパティ
    func hash(into hasher: inout Hasher) {
        hasher.combine(sourceNodeId)
        hasher.combine(targetNodeId)
    }
    
    static func == (lhs: NetworkEdge, rhs: NetworkEdge) -> Bool {
        // エッジはsourceとtargetの順序が異なっても同じとみなす
        (lhs.sourceNodeId == rhs.sourceNodeId && lhs.targetNodeId == rhs.targetNodeId) ||
        (lhs.sourceNodeId == rhs.targetNodeId && lhs.targetNodeId == rhs.sourceNodeId)
    }
}

// MARK: - ネットワークグラフ全体を管理する構造体
// この構造体は、グラフの構築と最短経路計算の結果を保持します
struct SocialNetworkGraph {
    var nodes: [String: NetworkNode] = [:] // UUIDをキーとしたノードの辞書
    var adjacencyList: [String: Set<String>] = [:] // 隣接リスト (UUIDをキー、接続しているノードのUUIDのSet)
    
    // ノードを追加
    mutating func addNode(_ node: NetworkNode) {
        nodes[node.id] = node
        adjacencyList[node.id] = adjacencyList[node.id] ?? []
    }
    
    // エッジを追加 (双方向)
    mutating func addEdge(from sourceId: String, to targetId: String) {
        guard nodes[sourceId] != nil && nodes[targetId] != nil else {
            print("⚠️ エッジ追加失敗: 存在しないノードIDが含まれています (\(sourceId) -> \(targetId))")
            return
        }
        adjacencyList[sourceId]?.insert(targetId)
        adjacencyList[targetId]?.insert(sourceId) // 双方向エッジ
    }
    
    // MARK: - 最短経路の計算 (BFS)
    mutating func calculateShortestPaths(from startNodeId: String) {
        // 全ノードの距離をリセット
        for id in nodes.keys {
            nodes[id]?.distance = -1 // 未到達
        }
        
        guard var startNode = nodes[startNodeId] else {
            print("❌ 最短経路計算失敗: 開始ノードが見つかりません: \(startNodeId)")
            return
        }
        
        var queue: [(nodeId: String, dist: Int)] = []
        
        startNode.distance = 0
        nodes[startNodeId] = startNode // 更新を反映
        queue.append((nodeId: startNodeId, dist: 0))
        
        var head = 0
        while head < queue.count {
            let (currentNodeId, currentDist) = queue[head]
            head += 1
            
            if let neighbors = adjacencyList[currentNodeId] {
                for neighborId in neighbors {
                    if var neighborNode = nodes[neighborId], neighborNode.distance == -1 {
                        neighborNode.distance = currentDist + 1
                        nodes[neighborId] = neighborNode
                        queue.append((nodeId: neighborId, dist: neighborNode.distance))
                    }
                }
            }
        }
        print("✅ 最短経路計算完了 (開始ノード: \(startNodeId))")
    }
    
    // MARK: - 連結成分の探索 (BFSベース)
    func findConnectedComponents() -> [[String]] {
        var components: [[String]] = []
        var visitedNodes: Set<String> = []
        
        for nodeId in nodes.keys {
            if !visitedNodes.contains(nodeId) {
                var currentComponent: [String] = []
                var queue: [String] = [nodeId]
                visitedNodes.insert(nodeId)
                
                var head = 0
                while head < queue.count {
                    let currentNodeId = queue[head]
                    head += 1
                    currentComponent.append(currentNodeId)
                    
                    if let neighbors = adjacencyList[currentNodeId] {
                        for neighborId in neighbors {
                            if !visitedNodes.contains(neighborId) {
                                visitedNodes.insert(neighborId)
                                queue.append(neighborId)
                            }
                        }
                    }
                }
                components.append(currentComponent)
            }
        }
        return components
    }
    
    // MARK: - 指定されたノードIDのセットから新しいグラフを抽出
    func extractGraph(from nodeIDs: Set<String>) -> SocialNetworkGraph {
        var newGraph = SocialNetworkGraph()
        
        for nodeId in nodeIDs {
            if let node = nodes[nodeId] {
                newGraph.addNode(node)
            }
        }
        
        for nodeId in nodeIDs {
            if let neighbors = adjacencyList[nodeId] {
                for neighborId in neighbors {
                    if nodeIDs.contains(neighborId) {
                        newGraph.addEdge(from: nodeId, to: neighborId)
                    }
                }
            }
        }
        return newGraph
    }
    
    // MARK: - 最大連結成分の抽出
    func extractLargestConnectedComponent() -> SocialNetworkGraph {
        let components = findConnectedComponents()
        
        guard let largestComponentNodeIDs = components.max(by: { $0.count < $1.count }) else {
            return SocialNetworkGraph()
        }
        
        let largestComponentGraph = extractGraph(from: Set(largestComponentNodeIDs))
        print("✅ 最大連結成分を抽出しました。ノード数: \(largestComponentGraph.nodes.count)")
        return largestComponentGraph
    }
}
