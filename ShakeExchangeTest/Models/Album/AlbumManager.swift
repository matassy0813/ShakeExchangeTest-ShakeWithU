//
//  AlbumManager.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//

import SwiftUI
import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import Combine
import FirebaseFunctions

class AlbumManager: ObservableObject {
    static let shared = AlbumManager()

    private var db: Firestore!
    private var storage: Storage!
    private var auth: Auth!
    var outerUIImage: UIImage? // ← 表示用画像キャッシュ
    var innerUIImage: UIImage?
    
    var outerImageURL: String?
    var outerImageData: UIImage?
    
    private let maxPhotosPerLoad = 100 // 一括ロードを防ぐ

    private init() {
        db = Firestore.firestore()
        storage = Storage.storage()
        auth = FirebaseAuth.Auth.auth() // FirebaseAuth.Auth.auth() に変更
    }

    // MARK: - 写真の保存とアップロード（メイン処理）
    /// 撮影した写真をローカルに保存し、Firebase Storageにアップロードし、Firestoreにメタデータを保存します。
    /// - Parameters:
    ///   - outerImage: 外側（メイン）のUIImage
    ///   - innerImage: 内側（サブ）のUIImage
    ///   - receivedUser: 写真を交換した相手のCurrentUser情報
    ///   - note: 写真に付随するメモ（オプション）
    /// - Returns: 保存されたAlbumPhotoオブジェクト、またはエラー
    func saveAndUploadPhoto(outerImage: UIImage, innerImage: UIImage, receivedUser: CurrentUser, note: String = "") async throws -> AlbumPhoto {
        guard let userId = auth.currentUser?.uid else {
            print("[AlbumManager] ❌ 写真保存失敗: ユーザーが認証されていません。")
            throw PhotoError.userNotAuthenticated
        }
        
        let currentUserProfile = await ProfileManager.shared.currentUser // 自分のプロフィールを取得

        // ユニークなファイル名を生成
        let uuid = UUID()
        let photoUUID = uuid.uuidString
        let outerImageFilename = "photo_\(photoUUID)_outer.jpg"
        let innerImageFilename = "photo_\(photoUUID)_inner.jpg"

        // MARK: 1. ローカルに画像を保存
        guard let localOuterURL = saveImageToDocuments(image: outerImage, filename: outerImageFilename),
              let localInnerURL = saveImageToDocuments(image: innerImage, filename: innerImageFilename) else {
            print("[AlbumManager] ❌ ローカル画像保存失敗")
            throw PhotoError.localSaveFailed
        }
        print("[AlbumManager] ✅ ローカル画像保存成功: \(outerImageFilename), \(innerImageFilename)")

        // MARK: 2. Firebase Storageに画像をアップロード
        let storagePath = "users/\(userId)/photos/\(photoUUID)"
        let outerStorageRef = storage.reference().child("\(storagePath)/\(outerImageFilename)")
        let innerStorageRef = storage.reference().child("\(storagePath)/\(innerImageFilename)")

        guard let outerImageData = outerImage.jpegData(compressionQuality: 0.8),
              let innerImageData = innerImage.jpegData(compressionQuality: 0.8) else {
            print("[AlbumManager] ❌ 画像データ変換失敗")
            throw PhotoError.imageConversionFailed
        }

        do {
            // putDataAsync は FirebaseStorage の新しいバージョンで提供されている async メソッド
            _ = try await outerStorageRef.putDataAsync(outerImageData)
            _ = try await innerStorageRef.putDataAsync(innerImageData)
            print("[AlbumManager] ✅ Storageアップロード成功")
        } catch {
            print("[AlbumManager] ❌ Storageアップロード失敗: \(error.localizedDescription)")
            throw PhotoError.storageUploadFailed(error)
        }

        // MARK: 3. Firestoreにメタデータを保存
        let newAlbumPhoto = AlbumPhoto(
            // ここで photoUUID を id として明示的に設定する
            id: uuid, // FirestoreのドキュメントIDと同じUUIDをAlbumPhotoのidに設定
            userUUID: userId,
            friendUUID: receivedUser.uuid,
            outerImage: "\(storagePath)/\(outerImageFilename)",
            innerImage: "\(storagePath)/\(innerImageFilename)",
            date: currentDateString(),
            note: note,
            rotation: Double.random(in: -5...5),
            pinColor: Color(hue: Double.random(in: 0...1), saturation: 0.7, brightness: 0.9),
            ownerName: currentUserProfile.name,
            ownerIcon: currentUserProfile.icon,
            friendNameAtCapture: receivedUser.name,
            friendIconAtCapture: receivedUser.icon,
            viewerUUIDs: [userId, receivedUser.uuid]
        )

        let albumPhotoRef = db.collection("users").document(userId).collection("albums").document(photoUUID)
        
        // MARK: 4. 共有フィード用コレクションにもメタデータを保存 (新しく追加)
        let feedPhotoRef = db.collection("feedPhotos").document(photoUUID)

        do {
            let data = try Firestore.Encoder().encode(newAlbumPhoto)
            try await albumPhotoRef.setData(data) // 自分のアルバムに保存
            try await feedPhotoRef.setData(data) // 共有フィード用コレクションに保存
            print("[AlbumManager] ✅ Firestoreメタデータ保存成功: \(photoUUID) (自分のアルバム & 共有フィード)")
        } catch {
            print("[AlbumManager] ❌ Firestoreメタデータ保存失敗: \(error.localizedDescription)")
            throw PhotoError.firestoreSaveFailed(error)
        }

        return newAlbumPhoto
    }

    // MARK: - アルバム写真の読み込み (自分のアルバム)
    /// 現在のユーザーのアルバム写真をFirestoreから読み込みます。
    /// - Returns: AlbumPhotoの配列
    func loadMyAlbumPhotos() async throws -> [AlbumPhoto] {
        guard let userId = auth.currentUser?.uid else {
            print("[AlbumManager] ⚠️ アルバム読み込み失敗: ユーザーが認証されていません。")
            return []
        }

        let albumCollectionRef = db.collection("users").document(userId).collection("albums")
        
        do {
            let querySnapshot = try await albumCollectionRef.getDocuments()
            let photos = try querySnapshot.documents.map { document in
                try document.data(as: AlbumPhoto.self)
            }
            print("[AlbumManager] ✅ 自分のアルバム写真読み込み成功 (\(photos.count)件)")
            return photos
        } catch {
            print("[AlbumManager] ❌ 自分のアルバム写真読み込み失敗: \(error.localizedDescription)")
            throw PhotoError.firestoreLoadFailed(error)
        }
    }
    
    // MARK: - 友達のアルバム写真の読み込み
    /// 特定の友達との写真をページング付きで読み込む
    /// - Parameters:
    ///   - friendUUID: 友達のUUID
    ///   - limit: 一度に読み込む写真の数
    ///   - lastDocument: 前回の読み込みの最後のドキュメント
    /// - Returns: 写真の配列と、次の読み込みに使うための最後のドキュメント
    func loadFriendAlbumPhotos(friendUUID: String, limit: Int = 20, startAfter lastDocument: DocumentSnapshot? = nil) async throws -> ([AlbumPhoto], DocumentSnapshot?) {
        guard let userId = auth.currentUser?.uid else { return ([], nil) }

        // "自分のアルバム"の中から"特定の友達"との写真だけをクエリで絞り込む
        var query: Query = db.collection("users").document(userId).collection("albums")
            .whereField("friendUUID", isEqualTo: friendUUID)
            .order(by: "date", descending: true)
            .limit(to: limit)

        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        let snapshot = try await query.getDocuments()
        // compactMapでデコード失敗したものを安全に除外
        let photos = try snapshot.documents.compactMap { try $0.data(as: AlbumPhoto.self) }
            
        print("[AlbumManager] ✅ 友達(\(friendUUID))のアルバム写真ページング読み込み成功 (\(photos.count)件)")
        return (photos, snapshot.documents.last)
    }

    // MARK: - 共有フィード写真の読み込み (新しく追加)
    /// 現在のユーザーが見るべき共有フィード写真をFirestoreから読み込みます。
    /// - Parameter userId: 現在のユーザーのUUID
    /// - Returns: AlbumPhotoの配列
//    func loadSharedFeedPhotos(for userId: String, limit: Int = 30) async throws -> [AlbumPhoto] {
//        let feedPhotosCollectionRef = db.collection("feedPhotos")
//        
//        do {
//            // viewerUUIDs 配列に自分のUUIDが含まれている写真をクエリ
//            let querySnapshot = try await feedPhotosCollectionRef
//                                        .whereField("viewerUUIDs", arrayContains: userId)
//                                        .order(by: "date", descending: true)
//                                        .limit(to: limit)
//                                        .getDocuments()
//            
//            let photos = try querySnapshot.documents.map { document in
//                try document.data(as: AlbumPhoto.self)
//            }
//            print("[AlbumManager] ✅ 共有フィード写真読み込み成功 (\(photos.count)件) for user: \(userId)")
//            return photos
//        } catch {
//            print("[AlbumManager] ❌ 共有フィード写真読み込み失敗: \(error.localizedDescription)")
//            throw PhotoError.firestoreLoadFailed(error)
//        }
//    }
    /// 共有フィード写真を読み込む（件数制限＆ページング対応）
    /// - Parameters:
    ///   - userId: 現在のユーザーUUID
    ///   - limit: 読み込み上限件数（デフォルト30）
    ///   - startAfter: 前回の最後のドキュメントスナップショット（任意）
    /// - Returns: AlbumPhoto配列と次回の読み込み開始点
    func loadSharedFeedPhotos(for userId: String, limit: Int = 30, startAfter: DocumentSnapshot? = nil) async throws -> ([AlbumPhoto], DocumentSnapshot?) {
        let feedPhotosCollectionRef = db.collection("feedPhotos")
            .whereField("viewerUUIDs", arrayContains: userId)
            .order(by: "date", descending: true)
            .limit(to: limit)

        let query = startAfter != nil
            ? feedPhotosCollectionRef.start(afterDocument: startAfter!)
            : feedPhotosCollectionRef

        do {
            let querySnapshot = try await query.getDocuments()
            let photos = try querySnapshot.documents.map { document in
                try document.data(as: AlbumPhoto.self)
            }
            print("[AlbumManager] ✅ 共有フィード写真読み込み成功 (\(photos.count)件) for user: \(userId)")
            return (photos, querySnapshot.documents.last)
        } catch {
            print("[AlbumManager] ❌ 共有フィード写真読み込み失敗: \(error.localizedDescription)")
            throw PhotoError.firestoreLoadFailed(error)
        }
    }



    func downloadImageWithSignedURL(photoId: String, completion: @escaping (UIImage?) -> Void) {
        let imageKey = "signed-\(photoId)" // 署名付きURL用のキャッシュキー
        // MARK: - 【修正1】キャッシュチェックを追加
        if let cachedImage = ImageCacheManager.shared.get(for: imageKey) {
            print("✅ [ImageCache] 署名URLキャッシュから画像を取得: \(imageKey)")
            completion(cachedImage)
            return
        }
        
        let functions = Functions.functions()
        // ここを修正: "getSignedFeedPhotoURL" から "getSignedFeedPhotoUrl" に変更
        functions.httpsCallable("getSignedFeedPhotoUrl").call(["photoId": photoId]) { result, error in
            if let error = error {
                print("❌ Failed to get signed URL: \(error)")
                completion(nil)
                return
            }

            guard let data = result?.data as? [String: Any],
                  let urlString = data["url"] as? String,
                  let url = URL(string: urlString) else {
                print("❌ Invalid URL data returned")
                completion(nil)
                return
            }

            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    // MARK: - 【修正2】ダウンロード後、画像をキャッシュに保存
                    ImageCacheManager.shared.set(image, for: imageKey)
                    print("📥 [ImageCache] 署名URL経由でダウンロードし、キャッシュに保存: \(imageKey)")
                    completion(image)
                } else {
                    completion(nil)
                }
            }.resume()
        }
    }
    
    /// アルバムをページング付きで読み込む（最初のロード量制限付き）
    /// - Parameters:
    ///   - limit: 最大取得件数（デフォルト: 30）
    ///   - startAfter: 続きから取得するためのDocumentSnapshot
    /// - Returns: 写真配列と、次のページの開始点になるDocumentSnapshot
    // AlbumManager.swift に追加

    // 自分のアルバム用
    func loadMyAlbumPhotos(limit: Int = 20, startAfter lastDocument: DocumentSnapshot? = nil) async throws -> ([AlbumPhoto], DocumentSnapshot?) {
        guard let userId = auth.currentUser?.uid else { return ([], nil) }

        var query = db.collection("users").document(userId).collection("albums")
            .order(by: "date", descending: true)
            .limit(to: limit)

        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }

        let snapshot = try await query.getDocuments()
        let photos = try snapshot.documents.compactMap { try $0.data(as: AlbumPhoto.self) }
        
        return (photos, snapshot.documents.last)
    }



    // MARK: - Storageからの画像ダウンロード
    /// Firebase Storageから画像をダウンロードします。
    /// - Parameter storagePath: Storage上のファイルのパス (例: "users/UID/photos/PHOTO_UUID/filename.jpg")
    /// - Returns: ダウンロードされたUIImage、またはnil
    // AlbumManager.swift の downloadImage 関数を修正

    func downloadImage(from storagePath: String) async -> UIImage? {
        // Storageパスが空の場合はダウンロードしない
        guard !storagePath.isEmpty else { return nil }

        // 1. キャッシュを確認
        if let cachedImage = ImageCacheManager.shared.get(for: storagePath) {
            // print("✅ [ImageCache] キャッシュから画像を取得: \(storagePath)")
            return cachedImage
        }

        let storageRef = storage.reference(withPath: storagePath)
        let maxSize: Int64 = 10 * 1024 * 1024

        // 2. キャッシュになければダウンロード
        do {
            let data = try await storageRef.data(maxSize: maxSize)
            if let image = UIImage(data: data) {
                // 3. ダウンロードした画像をキャッシュに保存
                ImageCacheManager.shared.set(image, for: storagePath)
                // print("📥 [ImageCache] 新規ダウンロード＆キャッシュ保存: \(storagePath)")
                return image
            }
            return nil
        } catch {
            print("❌ 画像ダウンロード失敗 (\(storagePath)): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - ヘルパー関数
    private func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func saveImageToDocuments(image: UIImage, filename: String) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return url
        } catch {
            print("❌ ローカル画像保存失敗 (\(filename)): \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - エラー定義
    enum PhotoError: Error, LocalizedError {
        case userNotAuthenticated
        case localSaveFailed
        case imageConversionFailed
        case storageUploadFailed(Error)
        case firestoreSaveFailed(Error)
        case firestoreLoadFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .userNotAuthenticated: return "ユーザーが認証されていません。"
            case .localSaveFailed: return "画像をローカルに保存できませんでした。"
            case .imageConversionFailed: return "画像データを変換できませんでした。"
            case .storageUploadFailed(let error): return "画像をクラウドにアップロードできませんでした: \(error.localizedDescription)"
            case .firestoreSaveFailed(let error): return "写真の情報をデータベースに保存できませんでした: \(error.localizedDescription)"
            case .firestoreLoadFailed(let error): return "アルバムの写真を読み込めませんでした: \(error.localizedDescription)"
            }
        }
    }
}
