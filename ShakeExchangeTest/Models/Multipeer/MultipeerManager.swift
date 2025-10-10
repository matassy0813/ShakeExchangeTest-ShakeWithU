//
//  MultipeerManager.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/23.
//

import MultipeerConnectivity
import Foundation
import CoreMotion
import UIKit // UIImage のために必要

class MultipeerManager: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    static let shared = MultipeerManager()
    private let serviceType = "shake-connect"

    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    private let motionManager = CMMotionManager()
    
    @Published var isHandshakeDetected: Bool = false
    @Published var isCommunicating: Bool = false

    var onReceiveUser: ((CurrentUser) -> Void)?

    override init() {
        super.init()
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self

        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self

        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        
        setupMotionManager()
    }

    func startAdvertising() {
        advertiser.startAdvertisingPeer()
        isCommunicating = true
    }

    func startBrowsing() {
        browser.startBrowsingForPeers()
    }

    @MainActor func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        resetSession()
        isCommunicating = false
    }
    
    @MainActor func resetSession() {
        print("[MultipeerManager] 🔄 セッションリセット開始")

        let oldSession = session
        let newSession = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        newSession.delegate = self

        // 先に差し替える（nil の瞬間を作らない）
        session = newSession

        // 最後に古い方を切断
        oldSession?.disconnect()

        print("[MultipeerManager] ✅ セッション新規作成済み")
    }



    func send(data: Data) {
        guard let session = session, !session.connectedPeers.isEmpty  else {
            print("[MultipeerManager] ⚠️ 接続ピアがありません。データ送信スキップ。")
            return
        }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            print("[MultipeerManager] 📤 データ送信成功 (\(data.count) bytes)")
        } catch {
            print("[MultipeerManager] ❌ データ送信失敗: \(error.localizedDescription)")
        }
    }
    
    private func setupMotionManager() {
        guard motionManager.isAccelerometerAvailable else {
            print("❌ Accelerometer not available")
            return
        }

        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let acceleration = data?.acceleration else { return }
            let shakeThreshold = 2.5
            if abs(acceleration.x) > shakeThreshold || abs(acceleration.y) > shakeThreshold || abs(acceleration.z) > shakeThreshold {
                // isHandshakeDetected が false の場合のみ検知処理を実行
                if !self.isHandshakeDetected {
                    self.detectHandshake()
                }
            }
        }
        print("✅ MotionManager started")
    }

    // MARK: - MCSessionDelegate
    @MainActor func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        if state == .connected {
            print("[MultipeerManager] 接続成功 with \(peerID.displayName)")
            sendCurrentUser()
        } else if state == .notConnected {
            print("[MultipeerManager] 接続切断: \(peerID.displayName)")
            // 接続が切断されたら、必要に応じて再探索を開始
            // self.detectHandshake() // 自動再探索が必要な場合
        }
    }

    // CurrentUserデータを送信
    @MainActor func sendCurrentUser() {
        let user = ProfileManager.shared.currentUser
        
        do {
            // まずCurrentUserオブジェクト全体をJSONEncoderでエンコード
            let encoder = JSONEncoder()
            let userData = try encoder.encode(user)
            
            // JSONデータを辞書に変換
            var jsonObject = try JSONSerialization.jsonObject(with: userData, options: []) as? [String: Any] ?? [:]
            
            // type フィールドを追加
            jsonObject["type"] = "profile"
            
            // アイコン画像をDataとして追加する場合
            if let image = loadUserIcon(named: user.icon) {
                // ★【修正点】送信前に画像をリサイズし、データサイズを削減
                let resizedImage = image.resized(to: CGSize(width: 100, height: 100)) // 100x100にリサイズ
                if let imageData = resizedImage.jpegData(compressionQuality: 0.8) { // JPEGに圧縮
                    jsonObject["iconData"] = imageData.base64EncodedString()
                    print("[MultipeerManager] ⚙️ アイコン画像をリサイズ＆Base64エンコードしました。Data size: \(imageData.count / 1024) KB")
                }
            }
            
            // 最終的な辞書をDataに戻して送信
            let finalData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
            send(data: finalData)
            print("[MultipeerManager] 📤 profile送信: \(user.uuid)")
        } catch {
            print("[MultipeerManager] ❌ profile送信失敗: \(error.localizedDescription)")
        }
    }

    // JSON受信処理（プロトコル制御）
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            do {
                
                guard let jsonString = String(data: data, encoding: .utf8) else {
                    print("[MultipeerManager] ❌ 無効なデータ（文字列変換不可）")
                    return
                }
                // まずは受信したデータを辞書としてパース
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    print("[MultipeerManager] ❌ 受信データが有効なJSON形式ではありません。")
                    return
                }
                
                guard let type = json["type"] as? String else {
                    print("[MultipeerManager] ❌ デコード失敗: 受信JSONに'type'フィールドがありません。")
                    return
                }
                
                print("[MultipeerManager] 🐞 受信JSON内容: \(json)")

                switch type {
                case "profile":
                    print("[MultipeerManager] 📥 profile受信")
                    
                    var mutableJson = json // jsonを可変にする

                    // iconDataがあればファイルに保存し、iconパスを更新
                    if let base64 = mutableJson["iconData"] as? String,
                       let imageData = Data(base64Encoded: base64) {
                        let filename = "received_icon_\(UUID().uuidString).jpg"
                        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
                        
                        do {
                            try imageData.write(to: fileURL)
                            mutableJson["icon"] = filename // iconプロパティをファイル名に更新
                            print("[MultipeerManager] ✅ 受信アイコン保存成功: \(filename)")
                        } catch {
                            print("[MultipeerManager] ❌ 受信アイコン保存失敗: \(error.localizedDescription)")
                        }
                        mutableJson.removeValue(forKey: "iconData") // iconDataはもう不要
                    }

                    // 更新されたJSON辞書をDataに戻し、CurrentUserとしてデコード
                    let updatedJsonData = try JSONSerialization.data(withJSONObject: mutableJson, options: [])
                    let user = try JSONDecoder().decode(CurrentUser.self, from: updatedJsonData)

                    let isNew = !FriendManager.shared.isExistingFriend(uuid: user.uuid)

                    let newFriend = Friend(
                        uuid: user.uuid,
                        name: user.name,
                        nickname: user.name, // 初期ニックネームとして相手のnameを設定
                        icon: user.icon,
                        description: user.description,
                        link: user.link,
                        addedDate: self.currentDateString(),
                        lastInteracted: self.currentDateString(),
                        challengeStatus: user.challengeStatus,
                        recentPhotos: user.recentPhotos
                    )

                    FriendManager.shared.update(friend: newFriend)

                    if isNew {
                        print("[MultipeerManager] ✅ 新規Friend追加")
                    } else {
                        print("[MultipeerManager] 🔄 既存Friend更新")
                        
                        FriendManager.shared.incrementEncounterCount(for: user.uuid)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            if let friend = FriendManager.shared.getFriend(by: user.uuid) {
                                FriendManager.shared.updateStreakCount(for: user.uuid, to: friend.streakCount ?? 1)
                            }
                        }
                        
                    }

                    self.onReceiveUser?(user)
                    // プロフィール受信後、確認メッセージを送信
                    self.sendConfirmationMessage(to: peerID)


                case "syk_ack": // 確認メッセージのタイプを統一
                    print("[MultipeerManager] 📥 syk_ack受信 → 通信完了 → 切断")
                    self.stop()

                default:
                    print("[MultipeerManager] ⚠️ 未知のデータtype: \(type)")
                }
            } catch {
                print("[MultipeerManager] ❌ データ処理失敗: \(error.localizedDescription)")
            }
        }
    }
    
    // 確認メッセージを送信する関数 (syk と ack を統合)
    // MultipeerManager.swift
    private func sendConfirmationMessage(to peerID: MCPeerID) {
        let payload: [String: Any] = ["type": "syk_ack"]
        guard
            let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
            let session = self.session,                       // ✅ nil防止
            !session.connectedPeers.isEmpty                   // ✅ 接続確認
        else {
            print("[MultipeerManager] ⚠️ ack送信スキップ（sessionなし/未接続）")
            return
        }
        do {
            try session.send(data, toPeers: [peerID], with: .reliable)
            print("[MultipeerManager] 📤 syk_ack 送信")
        } catch {
            print("[MultipeerManager] ❌ syk_ack 送信失敗: \(error.localizedDescription)")
        }
    }

    
    func detectHandshake() {
        DispatchQueue.main.async {
            self.isHandshakeDetected = true
            print("[MultipeerManager] 🤝 Handshake検知")

            // 通信開始
            self.startAdvertising()
            self.startBrowsing()
            print("[MultipeerManager] 📡 広告 & 探索 開始")

            // 4秒後に検知可能状態に戻す (ただし、接続が完了したら stop() でリセットされるため、このタイマーは補助的なもの)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                let connected = !(self.session?.connectedPeers.isEmpty ?? true)
                if connected {
                    print("[MultipeerManager] 🕓 検知リセット (接続中)")
                } else {
                    self.isHandshakeDetected = false
                    self.isCommunicating = false
                    print("[MultipeerManager] 🕓 検知リセット (未接続)")
                }
            }
        }
    }
    
    func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    func loadUserIcon(named filename: String) -> UIImage? {
        // アセットカタログからの読み込みを試行
        if let image = UIImage(named: filename) {
            return image
        }
        // ドキュメントディレクトリからの読み込みを試行
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
extension UIImage {
    func resized(to newSize: CGSize) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage ?? self
    }
}
