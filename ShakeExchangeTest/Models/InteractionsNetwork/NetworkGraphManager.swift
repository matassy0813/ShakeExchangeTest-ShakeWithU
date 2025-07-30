//
//  NetworkGraphManager.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/03.
//
import FirebaseFunctions
import Foundation
import Combine
import FirebaseFirestore // Firestoreをインポート
import FirebaseAuth

class NetworkGraphManager: ObservableObject {

    @Published var socialNetworkGraph: SocialNetworkGraph = SocialNetworkGraph()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Firebase Functions のインスタンス (Singleton として持つか、DI を検討)
    private let functions = Functions.functions(region: "us-central1") // リージョンはFunctionsに合わせてください

    // MARK: - ネットワークグラフのロード
    func loadNetworkGraph(for userId: String) async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }

        print("[NetworkGraphManager] 🚀 Loading network graph for userId: \(userId)")

        do {
            let result = try await functions.httpsCallable("getNetworkGraph").call(["userId": userId])
            print("[NetworkGraphManager] ✅ Cloud Function call succeeded")
            // 🔍 JSON全体のデバッグ出力
            if let jsonData = try? JSONSerialization.data(withJSONObject: result.data, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("[NetworkGraphManager] 📦 Full JSON response:\n\(jsonString)")
            }
            
            if let data = result.data as? [String: Any],
               let nodeDictionaries = data["nodes"] as? [[String: Any]],
               let edgeDictionaries = data["edges"] as? [[String: Any]] {

                print("[NetworkGraphManager] 📊 Nodes received: \(nodeDictionaries.count)")
                print("[NetworkGraphManager] 🔗 Edges received: \(edgeDictionaries.count)")

                var newGraph = SocialNetworkGraph()

                for nodeDict in nodeDictionaries {
                    if let id = nodeDict["id"] as? String,
                       let x = nodeDict["x"] as? Double,
                       let y = nodeDict["y"] as? Double {

                        let isCurrentUser = (id == userId)
                        let node = NetworkNode(
                            id: id,
                            name: "",
                            icon: "",
                            isCurrentUser: isCurrentUser,
                            position: CGPoint(x: x, y: y)
                        )
                        newGraph.addNode(node)
                    } else {
                        print("⚠️ Skipping node due to invalid format: \(nodeDict)")
                    }
                }

                for edgeDict in edgeDictionaries {
                    if let source = edgeDict["source"] as? String,
                       let target = edgeDict["target"] as? String {
                        newGraph.addEdge(from: source, to: target)
                    } else {
                        print("⚠️ Skipping edge due to invalid format: \(edgeDict)")
                    }
                }

                DispatchQueue.main.async {
                    self.socialNetworkGraph = newGraph
                    self.isLoading = false
                    print("[NetworkGraphManager] ✅ Network graph updated successfully.")
                }

            } else {
                print("[NetworkGraphManager] ❌ Unexpected data format in Cloud Function result: \(result.data)")
                DispatchQueue.main.async {
                    self.errorMessage = "Invalid data format"
                    self.isLoading = false
                }
            }
        } catch {
            print("[NetworkGraphManager] ❌ Error calling Cloud Function: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func sendMeet(to targetUserId: String, message: String = "meet!!") {
        let parameters: [String: Any] = [
            "fromUserId": Auth.auth().currentUser?.uid ?? "",
            "toUserId": targetUserId,
            "message": message
        ]
        
        functions.httpsCallable("sendMeet").call(parameters) { result, error in
            if let error = error {
                print("❌ Failed to send meet: \(error.localizedDescription)")
            } else {
                print("✅ meet!! sent to \(targetUserId) with message: \(message)")
            }
        }
    }


    struct NetworkGraphResponse: Codable {
        let nodes: [NetworkNodePayload]
        let edges: [EdgePayload]
    }

    struct NetworkNodePayload: Codable, Identifiable {
        let id: String
        let name: String
        let icon: String
        let position: PositionPayload
        let isCurrentUser: Bool
    }

    struct EdgePayload: Codable, Identifiable {
        var id: String { "\(sourceNodeId)-\(targetNodeId)" }
        let sourceNodeId: String
        let targetNodeId: String
    }

    struct PositionPayload: Codable {
        let x: CGFloat
        let y: CGFloat
    }
}
