//
//  FriendManager.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class FriendManager: ObservableObject {
    static let shared = FriendManager()

    @Published var friends: [Friend] = []

    private var db: Firestore!
    private var auth: Auth!
    private var friendsListener: ListenerRegistration?
    private let userDefaultsKey = "SavedFriends"

    private var cancellables = Set<AnyCancellable>()

    private init() {
        db = Firestore.firestore()
        auth = Auth.auth()
        
        AuthManager.shared.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                guard let self = self else { return }
                // MARK: - 堅牢性向上: AuthManager.shared.userId を使用
                if isAuthenticated, let userId = AuthManager.shared.userId {
                    print("[FriendManager] ✅ AuthManagerから認証通知受信: User ID = \(userId)")
                    self.startListeningForFriends(userId: userId)
                } else {
                    print("[FriendManager] ℹ️ AuthManagerから未認証通知受信。リスナーを停止し、ローカルデータをクリアします。")
                    self.stopListeningForFriends()
                    DispatchQueue.main.async {
                        self.friends.removeAll()
                        self.saveFriendsToUserDefaults()
                        print("[FriendManager] 🗑️ 未認証のためローカルのフレンドデータをクリアしました。")
                    }
                }
            }
            .store(in: &cancellables)

        loadFriendsFromUserDefaults()
    }
    
    // MARK: - 新規フレンドの追加
    func add(friend: Friend) {
        if !friends.contains(where: { $0.uuid == friend.uuid }) {
            Task { @MainActor in // MARK: - 堅牢性向上: Firestore操作はメインアクターからでも安全に呼び出せるが、UI更新はメインスレッド
                await saveFriendToFirestore(friend)
            }
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
        Task { @MainActor in // MARK: - 堅牢性向上: Firestore操作はメインアクターからでも安全に呼び出せるが、UI更新はメインスレッド
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
                DispatchQueue.main.async { // MARK: - 堅牢性向上: Publishedプロパティの更新はメインスレッドで
                    self.friends = savedFriends
                }
                print("[FriendManager] ✅ フレンドデータUserDefaults読み込み成功 (\(savedFriends.count)件)")
            } catch {
                print("[FriendManager] ❌ UserDefaults読み込み失敗: \(error.localizedDescription)")
            }
        } else {
            print("[FriendManager] ℹ️ UserDefaultsにフレンドデータが見つかりません。")
        }
    }

    // MARK: - フレンド保存 (Firestore)
    private func saveFriendToFirestore(_ friend: Friend) async {
        guard let userId = AuthManager.shared.userId else {
            print("[FriendManager] ⚠️ User IDが未設定のためFirestoreに保存できません。")
            return
        }
        
        let friendRef = db.collection("users").document(userId).collection("friends").document(friend.uuid)
        
        do {
            let data = try Firestore.Encoder().encode(friend)
            try await friendRef.setData(data)
            print("[FriendManager] ✅ Firestoreにフレンド保存完了: \(friend.name) (\(friend.uuid))")
        } catch {
            print("[FriendManager] ❌ Firestore保存失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - フレンド一覧読み込み (Firestore - リアルタイムリスナー)
    private func startListeningForFriends(userId: String) {
        stopListeningForFriends()
        
        let friendsCollectionRef = db.collection("users").document(userId).collection("friends")
        
        friendsListener = friendsCollectionRef.addSnapshotListener { [weak self] querySnapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[FriendManager] ❌ Firestoreリスナーエラー: \(error.localizedDescription)")
                return
            }
            
            guard let documents = querySnapshot?.documents else {
                print("[FriendManager] ℹ️ Firestoreにフレンドドキュメントがありません。")
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
                    // MARK: - 堅牢性向上: デコード失敗時の詳細ログ
                    print("[FriendManager] ❌ フレンドデータのデコード失敗 for document ID: \(document.documentID) Error: \(error.localizedDescription)")
                }
            }
            
            DispatchQueue.main.async {
                self.friends = fetchedFriends
                print("[FriendManager] ✅ Firestoreからフレンドデータ更新 (\(self.friends.count)件)")
                self.saveFriendsToUserDefaults()
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
    
    // MARK: - 堅牢性向上: encounterCountの更新をトランザクション推奨
    func incrementEncounterCount(for uuid: String) {
        guard let userId = AuthManager.shared.userId else {
            print("[FriendManager] ⚠️ User IDが未設定のためencounterCountを更新できません。")
            return
        }

        let friendRef = db.collection("users").document(userId).collection("friends").document(uuid)

        // MARK: - 堅牢性向上: トランザクションの使用を推奨 (競合状態防止)
        // ここでは既存のロジックを大きく変えないが、ベストプラクティスとしてはFirestore.runTransactionを使用
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let friendDocument: DocumentSnapshot
            do {
                try friendDocument = transaction.getDocument(friendRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard friendDocument.exists else {
                print("[FriendManager] ⚠️ incrementEncounterCount: 該当フレンドが見つかりません。UUID: \(uuid)")
                // 既存のドキュメントがない場合は、エラーとして処理するか、新規作成するかを検討
                // ここでは、エラーとして扱うため、トランザクションをキャンセル
                errorPointer?.pointee = NSError(domain: "FriendManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Friend not found."])
                return nil
            }
            
            let currentCount = friendDocument.get("encounterCount") as? Int ?? 0
            let lastStreakDateStr = friendDocument.get("lastStreakDate") as? String ?? ""
            let previousStreakCount = friendDocument.get("streakCount") as? Int ?? 0

            let today = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let todayString = formatter.string(from: today)

            var newStreakCount = 1
            if let lastStreakDate = formatter.date(from: lastStreakDateStr) {
                let daysSinceLast = Calendar.current.dateComponents([.day], from: lastStreakDate, to: today).day ?? 999
                if daysSinceLast == 1 { // 翌日の場合のみストリーク継続
                    newStreakCount = previousStreakCount + 1
                } else if daysSinceLast == 0 { // 同日の場合、ストリークは更新しない
                    newStreakCount = previousStreakCount
                } else { // 2日以上開いた場合、リセット
                    newStreakCount = 1
                }
            }
            
            transaction.setData([
                "encounterCount": currentCount + 1,
                "lastInteracted": todayString,
                "streakCount": newStreakCount,
                "lastStreakDate": todayString
            ], forDocument: friendRef, merge: true)
            
            print("[FriendManager] ✅ トランザクション: 再会カウント +1（\(currentCount + 1)）/ ストリーク更新（\(newStreakCount)）")
            return nil
        }) { (object, error) in
            if let error = error {
                print("[FriendManager] ❌ トランザクション失敗: \(error.localizedDescription)")
            } else {
                print("[FriendManager] ✅ トランザクション成功。")
            }
        }
    }
    
    func updateLocalEncounterCount(for uuid: String, to count: Int) {
        if let index = friends.firstIndex(where: { $0.uuid == uuid }) {
            DispatchQueue.main.async { // MARK: - 堅牢性向上: Publishedプロパティの更新はメインスレッドで
                self.friends[index].encounterCount = count
                self.saveFriendsToUserDefaults()
                print("[FriendManager] 💾 ローカルに encounterCount=\(count) を保存しました")
            }
        } else {
            print("[FriendManager] ⚠️ updateLocalEncounterCount: 該当フレンドが見つかりません。UUID: \(uuid)")
        }
    }
    
    func updateStreakCount(for uuid: String, to newValue: Int) {
        if let index = friends.firstIndex(where: { $0.uuid == uuid }) {
            DispatchQueue.main.async { // MARK: - 堅牢性向上: Publishedプロパティの更新はメインスレッドで
                self.friends[index].streakCount = newValue
                // ストリークのみの更新の場合、UserDefaultsへの保存も必要であれば追加
                // self.saveFriendsToUserDefaults()
            }
        } else {
            print("[FriendManager] ⚠️ updateStreakCount: 該当フレンドが見つかりません。UUID: \(uuid)")
        }
    }
    
    // MARK: - 全フレンドを削除（デバッグ用）
    func clearAllFriends() async {
        guard let userId = AuthManager.shared.userId else {
            print("[FriendManager] ⚠️ User IDが未設定のため全フレンドを削除できません。")
            return
        }
        
        let friendsCollectionRef = db.collection("users").document(userId).collection("friends")
        do {
            let documents = try await friendsCollectionRef.getDocuments().documents
            guard !documents.isEmpty else {
                print("[FriendManager] ℹ️ 削除するフレンドがいません。")
                return
            }
            
            // MARK: - 堅牢性向上: バッチ処理で削除
            let batch = db.batch()
            for document in documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()

            print("[FriendManager] 🗑️ Firestoreの全フレンドデータを削除しました。")
            DispatchQueue.main.async {
                self.friends.removeAll()
                self.saveFriendsToUserDefaults()
                print("[FriendManager] 🗑️ ローカルの全フレンドデータを削除しました。")
            }
        } catch {
            print("[FriendManager] ❌ 全フレンドデータ削除失敗: \(error.localizedDescription)")
        }
    }
}
