//
//  FriendManager.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//

import Foundation
import FirebaseFirestore // Firestoreをインポート
import FirebaseAuth // FirebaseAuthをインポート
import Combine // Combineフレームワークをインポート

class FriendManager: ObservableObject {
    static let shared = FriendManager()

    @Published var friends: [Friend] = []

    private var db: Firestore!
    private var auth: Auth!
    // userId は AuthManager から取得するため、ここでは直接保持しない
    // private var userId: String?
    private var friendsListener: ListenerRegistration? // Firestoreのリスナーを保持
    private let userDefaultsKey = "SavedFriends" // ローカル保存用キー

    // Combineフレームワークのcancellablesセットを追加
    private var cancellables = Set<AnyCancellable>()

    private init() {
        db = Firestore.firestore()
        auth = Auth.auth()
        
        // AuthManagerの認証状態変更を監視し、Firestoreリスナーの開始/停止をトリガー
        AuthManager.shared.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                guard let self = self else { return }
                if isAuthenticated, let userId = AuthManager.shared.userId {
                    print("[FriendManager] ✅ AuthManagerから認証通知受信: User ID = \(userId)")
                    self.startListeningForFriends(userId: userId) // 認証後、Firestoreのリスナーを開始
                } else {
                    print("[FriendManager] ℹ️ AuthManagerから未認証通知受信。")
                    self.stopListeningForFriends() // 未認証の場合、リスナーを停止
                    // ローカルのfriendsデータをクリア
                    DispatchQueue.main.async {
                        self.friends.removeAll()
                        self.saveFriendsToUserDefaults()
                        print("[FriendManager] 🗑️ 未認証のためローカルのフレンドデータをクリアしました。")
                    }
                }
            }
            .store(in: &cancellables)

        loadFriendsFromUserDefaults() // まずUserDefaultsから読み込みを試みる
    }
    
    // MARK: - 新規フレンドの追加
    func add(friend: Friend) {
        // UUIDで重複チェック
        if !friends.contains(where: { $0.uuid == friend.uuid }) {
            // ローカルに追加する前にFirestoreに保存を試みる
            Task {
                await saveFriendToFirestore(friend)
            }
            // Firestoreからのリアルタイム更新でfriends配列が更新されるため、ここでは直接appendしない
            print("[FriendManager] ✅ 新規フレンド追加リクエスト: \(friend.name) (\(friend.uuid))")
        } else {
            print("[FriendManager] ⚠️ 既存フレンドのため追加スキップ: \(friend.name) (\(friend.uuid))")
        }
    }

    // MARK: - 既知フレンドかどうか判定
    func isExistingFriend(uuid: String) -> Bool {
        return friends.contains { $0.uuid == uuid }
    }

    // MARK: - フレンド情報の更新
    func update(friend: Friend) {
        // ローカルを直接更新する代わりに、Firestoreに保存を試みる
        Task {
            await saveFriendToFirestore(friend)
        }
        print("[FriendManager] 🔄 フレンド更新リクエスト: \(friend.name) (\(friend.uuid))")
    }

    // MARK: - フレンド保存 (UserDefaults)
    private func saveFriendsToUserDefaults() {
        do {
            let data = try JSONEncoder().encode(friends)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            print("[FriendManager] ✅ フレンドデータUserDefaults保存完了 (\(friends.count)件)")
        } catch {
            print("[FriendManager] ❌ UserDefaults保存失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - フレンド読み込み (UserDefaults)
    private func loadFriendsFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let savedFriends = try JSONDecoder().decode([Friend].self, from: data)
                friends = savedFriends
                print("[FriendManager] ✅ フレンドデータUserDefaults読み込み成功 (\(friends.count)件)")
            } catch {
                print("[FriendManager] ❌ UserDefaults読み込み失敗: \(error.localizedDescription)")
            }
        } else {
            print("[FriendManager] ℹ️ UserDefaultsにフレンドデータが見つかりません。")
        }
    }

    // MARK: - フレンド保存 (Firestore)
    private func saveFriendToFirestore(_ friend: Friend) async {
        guard let userId = AuthManager.shared.userId else { // AuthManagerからuserIdを取得
            print("[FriendManager] ⚠️ User IDが未設定のためFirestoreに保存できません。")
            return
        }
        
        // Firestoreのパス: /users/{userId}/friends/{friend.uuid}
        let friendRef = db.collection("users").document(userId).collection("friends").document(friend.uuid)
        
        do {
            // Friendオブジェクト全体をエンコード
            let data = try Firestore.Encoder().encode(friend)
            try await friendRef.setData(data)
            print("[FriendManager] ✅ Firestoreにフレンド保存完了: \(friend.name) (\(friend.uuid))")
            // Firestoreからのリアルタイム更新でfriends配列が更新されるため、ここではsaveFriendsToUserDefaultsを直接呼ばない
            // リスナー内でUserDefaultsへの保存も行われる
        } catch {
            print("[FriendManager] ❌ Firestore保存失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - フレンド一覧読み込み (Firestore - リアルタイムリスナー)
    private func startListeningForFriends(userId: String) { // userIdを引数で受け取る
        stopListeningForFriends() // 既存のリスナーがあれば停止
        
        let friendsCollectionRef = db.collection("users").document(userId).collection("friends")
        
        // onSnapshotでリアルタイム更新を監視
        friendsListener = friendsCollectionRef.addSnapshotListener { [weak self] querySnapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[FriendManager] ❌ Firestoreリスナーエラー: \(error.localizedDescription)")
                return
            }
            
            guard let documents = querySnapshot?.documents else {
                print("[FriendManager] ℹ️ Firestoreにフレンドドキュメントがありません。")
                // ドキュメントがない場合もローカルのfriendsをクリアし、UserDefaultsも更新
                DispatchQueue.main.async {
                    self.friends.removeAll()
                    self.saveFriendsToUserDefaults()
                    print("[FriendManager] ℹ️ Firestoreにフレンドドキュメントがないため、ローカルデータをクリアしました。")
                }
                return
            }
            
            var fetchedFriends: [Friend] = []
            for document in documents {
                do {
                    let friend = try document.data(as: Friend.self)
                    fetchedFriends.append(friend)
                } catch {
                    print("[FriendManager] ❌ フレンドデータのデコード失敗: \(error.localizedDescription)")
                }
            }
            
            DispatchQueue.main.async {
                self.friends = fetchedFriends
                print("[FriendManager] ✅ Firestoreからフレンドデータ更新 (\(self.friends.count)件)")
                self.saveFriendsToUserDefaults() // Firestoreから読み込み成功後、UserDefaultsも更新
            }
        }
        print("[FriendManager] ✅ Firestoreフレンドリスナー開始")
    }
    
    // MARK: - リスナー停止
    private func stopListeningForFriends() {
        friendsListener?.remove()
        friendsListener = nil
        print("[FriendManager] 🛑 Firestoreフレンドリスナー停止")
    }
    
    func incrementEncounterCount(for uuid: String) {
        guard let userId = AuthManager.shared.userId else {
            print("[FriendManager] ⚠️ 認証されていません")
            return
        }

        let friendRef = db.collection("users").document(userId).collection("friends").document(uuid)

        friendRef.getDocument { (document, error) in
            if let document = document, document.exists {
                let currentCount = document.get("encounterCount") as? Int ?? 0
                friendRef.setData([
                    "encounterCount": currentCount + 1,
                    "lastInteracted": DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
                ], merge: true)
                print("[FriendManager] ✅ 再会カウント +1（\(currentCount + 1)）")
            } else {
                print("[FriendManager] ⚠️ 該当フレンドが見つかりません")
            }
        }
    }
    
    func updateLocalEncounterCount(for uuid: String, to count: Int) {
        if let index = friends.firstIndex(where: { $0.uuid == uuid }) {
            friends[index].encounterCount = count
            saveFriendsToUserDefaults()
            print("[FriendManager] 💾 ローカルに encounterCount=\(count) を保存しました")
        }
    }
    
    func updateStreakCount(for uuid: String, to newValue: Int) {
        if let index = friends.firstIndex(where: { $0.uuid == uuid }) {
            friends[index].streakCount = newValue
        }
    }
    
    // MARK: - 全フレンドを削除（デバッグ用）
    func clearAllFriends() async {
        guard let userId = AuthManager.shared.userId else { // AuthManagerからuserIdを取得
            print("[FriendManager] ⚠️ User IDが未設定のため全フレンドを削除できません。")
            return
        }
        
        let friendsCollectionRef = db.collection("users").document(userId).collection("friends")
        do {
            let documents = try await friendsCollectionRef.getDocuments().documents
            for document in documents {
                try await document.reference.delete()
            }
            print("[FriendManager] 🗑️ Firestoreの全フレンドデータを削除しました。")
            // ローカルデータはリスナーによって自動的にクリアされるはずだが、念のため明示的にクリア
            DispatchQueue.main.async {
                self.friends.removeAll()
                self.saveFriendsToUserDefaults() // UserDefaultsもクリア
                print("[FriendManager] 🗑️ ローカルの全フレンドデータを削除しました。")
            }
        } catch {
            print("[FriendManager] ❌ 全フレンドデータ削除失敗: \(error.localizedDescription)")
        }
    }
}
