//
//  FriendFoundView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/21.
//

import SwiftUI
import FirebaseFirestore
import CoreLocation

struct FriendFoundView: View {
    var receivedUser: CurrentUser
    
    var friendName: String
    var friendImage: String
    var userImage: String = ProfileManager.shared.currentUser.icon
    
    @State private var nickname: String = "" // ユーザーが入力するニックネーム
    @State private var showError: Bool = false
    @State private var navigateToCamera = false // カメラビューへの遷移フラグ
    @State private var encounterCount: Int? = nil
    @State private var isNewFriend: Bool // 新規フレンドかどうかを管理
    
    @StateObject private var locationManager = LocationManager()

    @Environment(\.presentationMode) var presentationMode // このビューを閉じるため

    init(receivedUser: CurrentUser) {
        self.receivedUser = receivedUser
        self.friendName = receivedUser.name
        self.friendImage = receivedUser.icon
        
        // receivedUserのUUIDがFriendManagerに存在するかで新規フレンドかどうかを判定
        _isNewFriend = State(initialValue: !FriendManager.shared.isExistingFriend(uuid: receivedUser.uuid))
        // 新規フレンドの場合、初期ニックネームとして相手の名前を設定
        _nickname = State(initialValue: receivedUser.name)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(colors: [Color.blue.opacity(0.1), Color.cyan.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 30) {
                    // 通知バナー風
                    HStack {
                        Image(systemName: "hands.sparkles.fill")
                            .foregroundColor(.blue)
                        Text("Connected with \(friendName)!")
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // 人型シルエット＋アイコン埋め込み
                    HStack(spacing: 40) {
                        VStack {
                            ZStack {
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.blue.opacity(0.2))

                                if let uiImage = loadUserIcon(named: userImage) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .clipShape(Circle())
                                        .frame(width: 60, height: 60)
                                } else {
                                    Image(userImage)
                                        .resizable()
                                        .clipShape(Circle())
                                        .frame(width: 60, height: 60)
                                }
                            }
                            Text("You")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        VStack {
                            ZStack {
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.blue.opacity(0.2))

                                if let uiImage = loadUserIcon(named: friendImage) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .clipShape(Circle())
                                        .frame(width: 60, height: 60)
                                } else {
                                    Image(friendImage)
                                        .resizable()
                                        .clipShape(Circle())
                                        .frame(width: 60, height: 60)
                                }
                            }
                            Text(friendName)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    // メッセージ
                    Text("Connected!")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    if let count = encounterCount {
                        Text("You've met this friend \(count) time\(count > 1 ? "s" : "")!")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Text("Tap below to take a photo.")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    // 新規フレンドの場合のみニックネーム入力欄を表示
                    if isNewFriend {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Set a Nickname for \(friendName)")
                                .font(.headline)
                                .padding(.top, 10)

                            TextField("e.g. Emi, Classmate, etc.", text: $nickname)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)

                            if showError {
                                Text("Nickname can't be empty.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }

                            Button(action: {
                                if nickname.trimmingCharacters(in: .whitespaces).isEmpty {
                                    showError = true
                                } else {
                                    // 保存処理: 入力されたニックネームを渡す
                                    saveNewFriend(nickname: nickname)
                                    navigateToCamera = true
                                }
                            }) {
                                Text("Save Nickname & Take Photo") // ボタンテキストを変更
                                    .fontWeight(.bold)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top)
                    } else {
                        // 既存フレンドの場合は直接カメラへ進むボタンのみ表示
                        Button(action: {
                            navigateToCamera = true
                        }) {
                            Text("Take a Photo")
                                .fontWeight(.bold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    // NavigationLink遷移先
                    NavigationLink(
                        destination: CameraView(
                            receivedUser: receivedUser,
                            friendName: friendName,
                            friendIcon: friendImage,
                            userIcon: userImage
                        ),
                        isActive: $navigateToCamera
                    ) {
                        EmptyView()
                    }
                    .onDisappear { // CameraViewが閉じられたら
                        // presentationMode.wrappedValue.dismiss() // この行を削除またはコメントアウト
                        print("[FriendFoundView] CameraViewが閉じられました。")
                    }
                }
                .padding(.top, 40)
            }
        }
        .onAppear {
            let userId = AuthManager.shared.userId ?? "unknown"
            let docRef = Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("friends")
                .document(receivedUser.uuid)

            docRef.getDocument { (document, error) in
                let today = Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let todayString = formatter.string(from: today)

                var newEncounterCount = 1
                var newStreakCount = 1

                if let document = document, document.exists {
                    // 🔁 Firestoreから現在のカウントなどを取得
                    let currentCount = document.get("encounterCount") as? Int ?? 0
                    newEncounterCount = currentCount + 1
                    let lastStreakDateStr = document.get("lastStreakDate") as? String ?? ""
                    let previousStreakCount = document.get("streakCount") as? Int ?? 0

                    if let lastStreakDate = formatter.date(from: lastStreakDateStr) {
                        let daysSinceLast = Calendar.current.dateComponents([.day], from: lastStreakDate, to: today).day ?? 999
                        if daysSinceLast <= 3 {
                            newStreakCount = previousStreakCount + 1
                        } else {
                            newStreakCount = 1
                        }
                    }

                    // ✅ Firestore に更新
                    docRef.setData([
                        "encounterCount": newEncounterCount,
                        "lastInteracted": todayString,
                        "streakCount": newStreakCount,
                        "lastStreakDate": todayString
                    ], merge: true)

                    // ✅ ローカルにも反映
                    FriendManager.shared.updateLocalEncounterCount(for: receivedUser.uuid, to: newEncounterCount)
                    FriendManager.shared.updateStreakCount(for: receivedUser.uuid, to: newStreakCount)

                    // ✅ 表示用
                    encounterCount = newEncounterCount
                    print("[FriendFoundView] ✅ 再会回数: \(newEncounterCount) / ストリーク: \(newStreakCount)")

                } else {
                    // 🆕 初回登録
                    docRef.setData([
                        "encounterCount": 1,
                        "lastInteracted": todayString,
                        "streakCount": 1,
                    ], merge: true)

                    FriendManager.shared.updateLocalEncounterCount(for: receivedUser.uuid, to: 1)
                    FriendManager.shared.updateStreakCount(for: receivedUser.uuid, to: 1)

                    encounterCount = 1
                    print("[FriendFoundView] 🆕 初回再会記録 / ストリーク開始")
                }
            }
        }
        .onReceive(locationManager.$location.compactMap { $0 }) { coordinate in
            print("📍 Firestore記録を開始（座標取得済み）")
            saveEncounterWithLocation(coordinate: coordinate)
        }
    }
    
    func saveEncounterWithLocation(coordinate: CLLocationCoordinate2D) {
        let userId = AuthManager.shared.userId ?? "unknown"
        let docRef = Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("friends")
            .document(receivedUser.uuid)

        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: today)

        let latitude = coordinate.latitude
        let longitude = coordinate.longitude

        docRef.getDocument { (document, error) in
            var newEncounterCount = 1
            var newStreakCount = 1

            if let document = document, document.exists {
                let currentCount = document.get("encounterCount") as? Int ?? 0
                newEncounterCount = currentCount + 1
                let lastStreakDateStr = document.get("lastStreakDate") as? String ?? ""
                let previousStreakCount = document.get("streakCount") as? Int ?? 0

                if let lastStreakDate = formatter.date(from: lastStreakDateStr) {
                    let daysSinceLast = Calendar.current.dateComponents([.day], from: lastStreakDate, to: today).day ?? 999
                    newStreakCount = (daysSinceLast <= 3) ? previousStreakCount + 1 : 1
                }
            }

            docRef.setData([
                "encounterCount": newEncounterCount,
                "lastInteracted": todayString,
                "streakCount": newStreakCount,
                "lastStreakDate": todayString,
                "lastLocation": GeoPoint(latitude: latitude, longitude: longitude)
            ], merge: true)

            FriendManager.shared.updateLocalEncounterCount(for: receivedUser.uuid, to: newEncounterCount)
            FriendManager.shared.updateStreakCount(for: receivedUser.uuid, to: newStreakCount)
            encounterCount = newEncounterCount

            print("[FriendFoundView] ✅ Firestoreに記録しました (lat: \(latitude), lon: \(longitude))")
        }
    }

    
    func loadUserIcon(named filename: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
    
    // ニックネームを引数として受け取るように変更
    func saveNewFriend(nickname: String) {
        let newFriend = Friend(
            uuid: receivedUser.uuid,
            name: nickname,                     // 自分で設定した名前 (ニックネーム)
            nickname: receivedUser.name,        // 相手の自己申告名 (元のname)
            icon: receivedUser.icon,
            description: receivedUser.description,
            link: receivedUser.link,
            addedDate: currentDateString(),
            lastInteracted: currentDateString(),
            challengeStatus: receivedUser.challengeStatus,
            recentPhotos: receivedUser.recentPhotos
        )
        FriendManager.shared.add(friend: newFriend)
    }
    
    func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
