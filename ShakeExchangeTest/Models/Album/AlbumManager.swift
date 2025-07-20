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

class AlbumManager: ObservableObject {
    static let shared = AlbumManager()

    private var db: Firestore!
    private var storage: Storage!
    private var auth: Auth!

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
        
        let currentUserProfile = ProfileManager.shared.currentUser // 自分のプロフィールを取得

        // ユニークなファイル名を生成
        let photoUUID = UUID().uuidString
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
            userUUID: userId, // 自分のUUID (Firebase Auth UID)
            friendUUID: receivedUser.uuid, // 相手のUUID
            outerImage: "\(storagePath)/\(outerImageFilename)", // Storageパスを保存
            innerImage: "\(storagePath)/\(innerImageFilename)", // Storageパスを保存
            date: currentDateString(),
            note: note,
            rotation: Double.random(in: -5...5), // ランダムな傾き
            pinColor: Color(hue: Double.random(in: 0...1), saturation: 0.7, brightness: 0.9), // ランダムなピン色
            ownerName: currentUserProfile.name, // 自分の名前を記録
            ownerIcon: currentUserProfile.icon, // 自分のアイコンパスを記録
            friendNameAtCapture: receivedUser.name, // 相手の名前を記録
            friendIconAtCapture: receivedUser.icon, // 相手のアイコンパスを記録
            viewerUUIDs: [userId, receivedUser.uuid] // 撮影者と相手のUUIDを含める
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
    /// 特定の友達と自分が写っている写真をFirestoreから読み込みます。
    /// これは、その友達のアルバム（自分が撮影したその友達との写真）と、
    /// その友達が撮影した自分との写真の両方を含む可能性があります。
    /// 現時点では、自分のアルバムからその友達との写真のみをフィルタリングします。
    /// 将来的には、友達の公開アルバムからも写真を読み込むロジックを追加できます。
    func loadFriendAlbumPhotos(friendUUID: String) async throws -> [AlbumPhoto] {
        guard let userId = auth.currentUser?.uid else {
            print("[AlbumManager] ⚠️ 友達アルバム読み込み失敗: ユーザーが認証されていません。")
            return []
        }

        // 自分のアルバムから、指定されたfriendUUIDを持つ写真のみをフィルタリング
        let myPhotos = try await loadMyAlbumPhotos()
        let friendPhotos = myPhotos.filter { $0.friendUUID == friendUUID }
        
        print("[AlbumManager] ✅ 友達アルバム写真読み込み成功 (\(friendPhotos.count)件) for friend: \(friendUUID)")
        return friendPhotos
    }

    // MARK: - 共有フィード写真の読み込み (新しく追加)
    /// 現在のユーザーが見るべき共有フィード写真をFirestoreから読み込みます。
    /// - Parameter userId: 現在のユーザーのUUID
    /// - Returns: AlbumPhotoの配列
    func loadSharedFeedPhotos(for userId: String) async throws -> [AlbumPhoto] {
        let feedPhotosCollectionRef = db.collection("feedPhotos")
        
        do {
            // viewerUUIDs 配列に自分のUUIDが含まれている写真をクエリ
            let querySnapshot = try await feedPhotosCollectionRef
                                        .whereField("viewerUUIDs", arrayContains: userId)
                                        .getDocuments()
            
            let photos = try querySnapshot.documents.map { document in
                try document.data(as: AlbumPhoto.self)
            }
            print("[AlbumManager] ✅ 共有フィード写真読み込み成功 (\(photos.count)件) for user: \(userId)")
            return photos
        } catch {
            print("[AlbumManager] ❌ 共有フィード写真読み込み失敗: \(error.localizedDescription)")
            throw PhotoError.firestoreLoadFailed(error)
        }
    }

    // MARK: - Storageからの画像ダウンロード
    /// Firebase Storageから画像をダウンロードします。
    /// - Parameter storagePath: Storage上のファイルのパス (例: "users/UID/photos/PHOTO_UUID/filename.jpg")
    /// - Returns: ダウンロードされたUIImage、またはnil
    func downloadImage(from storagePath: String) async -> UIImage? {
        // Storageパスが空の場合はダウンロードしない
        guard !storagePath.isEmpty else { return nil }

        let storageRef = storage.reference(withPath: storagePath)
        
        // 最大ダウンロードサイズを10MBに設定
        let maxSize: Int64 = 10 * 1024 * 1024
        
        // withCheckedContinuation を使ってコールバックベースの API を async/await に変換
        return await withCheckedContinuation { continuation in
            storageRef.getData(maxSize: maxSize) { data, error in
                if let error = error {
                    print("[AlbumManager] ❌ 画像ダウンロード失敗 (\(storagePath)): \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else if let data = data {
                    continuation.resume(returning: UIImage(data: data))
                } else {
                    print("[AlbumManager] ❌ 画像データが見つかりません (\(storagePath))")
                    continuation.resume(returning: nil)
                }
            }
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
