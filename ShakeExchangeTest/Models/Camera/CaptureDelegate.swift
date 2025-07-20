//
//  CaptureDelegate.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/27.
//

import Foundation
import AVFoundation
import UIKit

class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    let completion: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let data = photo.fileDataRepresentation(),
           let image = UIImage(data: data) {
            completion(image)
        } else {
            completion(nil)
        }
    }
}
