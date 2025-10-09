//
//  MeetMessageView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/07/29.
//
import SwiftUI
import Combine
import Foundation

struct MeetMessageView: View {
    let targetNode: NetworkNode
    var onSend: (String) -> Void

    @Environment(\.presentationMode) var presentationMode
    @State private var message: String = "meet!!"
    @State private var isSending = false
    @State private var showSuccess = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Send to \(targetNode.name)")) {
                    TextField("Message", text: $message)
                }

                Section {
                    Button(action: sendMessage) {
                        if isSending {
                            ProgressView()
                        } else {
                            Text("meet!!を送ろう🎉")
                        }
                    }
                    .disabled(isSending || message.isEmpty)
                }

                if showSuccess {
                    Text("🎉 meet!! sent successfully!")
                        .foregroundColor(.green)
                }
            }
            .navigationTitle("Send meet!!")
            .navigationBarTitleDisplayMode(.inline)                   // ①
            .toolbarBackground(.visible, for: .navigationBar)         // ②
            .toolbarBackground(Color.black, for: .navigationBar)      // ③
            .toolbarColorScheme(.dark, for: .navigationBar)           // ④
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func sendMessage() {
        isSending = true
        onSend(message)
        showSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            presentationMode.wrappedValue.dismiss()
        }
    }
}
