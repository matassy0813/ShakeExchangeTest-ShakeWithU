//
//  CameraManager.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//
import Foundation
import AVFoundation
import UIKit
import Combine
import SwiftUI

class CameraManager: NSObject, ObservableObject {
    var session = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var currentCamera: AVCaptureDevice.Position = .back
    private var videoInput: AVCaptureDeviceInput?
    private var photoOutput = AVCapturePhotoOutput()
    
    private var photoCaptureProcessor: PhotoCaptureProcessor?

    // カメラアクセス権限の状態
    @Published var permissionGranted: Bool = false
    
    override init() {
        super.init()
        checkCameraPermission() // 初期化時に権限を確認
    }

    // MARK: - カメラ権限の確認と要求
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            configureSession() // 権限があればセッションを設定
            print("[CameraManager] ✅ カメラ権限が許可されています。")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.configureSession() // 許可されたらセッションを設定
                        print("[CameraManager] ✅ カメラ権限が許可されました。")
                    } else {
                        print("[CameraManager] ❌ カメラ権限が拒否されました。")
                    }
                }
            }
        case .denied, .restricted:
            permissionGranted = false
            print("[CameraManager] ❌ カメラ権限が拒否または制限されています。")
        @unknown default:
            permissionGranted = false
            print("[CameraManager] ⚠️ 未知のカメラ権限ステータス。")
        }
    }

    // MARK: - カメラセッションの設定
    func configureSession() {
        // 既にセッションが設定済みで、権限もあれば再設定しない
        guard permissionGranted else {
            print("[CameraManager] ⚠️ カメラ権限がないためセッションを設定できません。")
            return
        }
        
        // 既にセッションが実行中の場合は停止してから再設定
        if session.isRunning {
            session.stopRunning()
            print("[CameraManager] 🔄 既存セッションを停止しました。")
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        // 既存入力・出力削除
        if let currentInput = videoInput {
            session.removeInput(currentInput)
            videoInput = nil // 確実にnilにする
        }
        for output in session.outputs {
            session.removeOutput(output)
        }
        photoOutput = AVCapturePhotoOutput() // 再作成

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCamera) else {
            print("❌ カメラが見つかりません。")
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
                videoInput = input
                print("[CameraManager] ✅ カメラ入力追加成功。")
            } else {
                print("[CameraManager] ❌ カメラ入力の追加に失敗しました。")
                session.commitConfiguration()
                return
            }

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                print("[CameraManager] ✅ 写真出力追加成功。")
            } else {
                print("[CameraManager] ❌ 写真出力の追加に失敗しました。")
                session.commitConfiguration()
                return
            }

            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer?.videoGravity = .resizeAspectFill
            print("[CameraManager] ✅ PreviewLayer設定完了。")

        } catch {
            print("[CameraManager] ❌ カメラ入力設定エラー: \(error.localizedDescription)")
            session.commitConfiguration()
            return
        }

        session.commitConfiguration()
        print("[CameraManager] ✅ セッション設定完了。")
    }

    // MARK: - セッションの開始
    func startSession() {
        guard permissionGranted else {
            print("[CameraManager] ⚠️ カメラ権限がないためセッションを開始できません。")
            return
        }
        guard !session.isRunning else {
            print("[CameraManager] ℹ️ セッションは既に実行中です。")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            print("[CameraManager] ✅ セッション開始。")
        }
    }

    // MARK: - セッションの停止
    func stopSession() {
        guard session.isRunning else {
            print("[CameraManager] ℹ️ セッションは既に停止しています。")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
            print("[CameraManager] 🛑 セッション停止。")
        }
    }

    // MARK: - カメラの切り替え
    func flipCamera() {
        session.beginConfiguration()
        if let currentInput = videoInput {
            session.removeInput(currentInput)
        }
        currentCamera = currentCamera == .back ? .front : .back

        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCamera),
              let newInput = try? AVCaptureDeviceInput(device: newCamera),
              session.canAddInput(newInput) else {
            print("❌ カメラ切替失敗: 新しいカメラ入力の追加に失敗しました。")
            session.commitConfiguration()
            return
        }

        session.addInput(newInput)
        videoInput = newInput
        session.commitConfiguration()
        startSession()  // 切替後に再開必須！
        print("[CameraManager] 🔄 カメラ切替: \(currentCamera == .back ? "Back" : "Front")")
    }

    // MARK: - 写真の撮影
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        if !session.isRunning {
            print("❌ session が動いていません。写真撮影をスキップします。")
            completion(nil) // セッションが動いていなければnilを返す
            return
        }
        if photoOutput.connections.isEmpty {
            print("❌ photoOutput に接続がありません。写真撮影をスキップします。")
            completion(nil)
            return
        }

        let settings = AVCapturePhotoSettings()
        // フラッシュモードを自動に設定 (必要であれば)
//        if photoOutput.isFlashSceneDetectionEnabled {
//            settings.flashMode = .auto
//        }
        
        // 強参照を保持してデリゲートが解放されないようにする
        let processor = PhotoCaptureProcessor(completion: completion)
        photoCaptureProcessor = processor
        
        photoOutput.capturePhoto(with: settings, delegate: processor)
        print("[CameraManager] 📸 写真撮影要求。")
    }
}

