//
//  ProfileEditView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//
import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @Binding var user: CurrentUser

    @State private var draftName: String
    @State private var draftLink: String
    @State private var draftIcon: UIImage?
    @State private var imageSelection: PhotosPickerItem?
    @State private var draftDescription: String

    
    @ObservedObject var profileManager = ProfileManager.shared

    @Environment(\.dismiss) private var dismiss

    init(user: Binding<CurrentUser>) {
        self._user = user
        _draftName = State(initialValue: user.wrappedValue.name)
        _draftLink = State(initialValue: user.wrappedValue.link)
        _draftDescription = State(initialValue: user.wrappedValue.description)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Edit Profile")
                    .font(.title)
                    .bold()
                    .foregroundColor(.purple)
                    .padding(.top)

                if let draftIcon = draftIcon {
                    Image(uiImage: draftIcon)
                        .resizable()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Image(user.icon)
                        .resizable()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                }

                PhotosPicker(selection: $imageSelection, matching: .images) {
                    Text("Select Profile Icon")
                        .foregroundColor(.blue)
                }
                .onChange(of: imageSelection) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            draftIcon = uiImage
                        }
                    }
                }

                VStack(alignment: .leading) {
                    Text("Name")
                    TextField("Enter name", text: $draftName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading) {
                    Text("Description")
                    TextField("About you", text: $draftDescription, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...5)
                }

                VStack(alignment: .leading) {
                    Text("Profile URL")
                    TextField("https://lit.link/yourname", text: $draftLink)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }


                Button(action: {
                    profileManager.currentUser.name = draftName
                    profileManager.currentUser.link = draftLink
                    profileManager.currentUser.description = draftDescription

                    if let image = draftIcon {
                        let filename = "profile_icon_\(UUID().uuidString).jpg"
                        if let url = saveImageToDocuments(image: image, filename: filename) {
                            profileManager.currentUser.icon = url.lastPathComponent
                        }
                    }
                    dismiss()
                }) {
                    Text("Save")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
    }

    // MARK: - Image Saving Helper
    func saveImageToDocuments(image: UIImage, filename: String) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }

        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)

        do {
            try data.write(to: url)
            return url
        } catch {
            print("❌ Failed to save image: \(error)")
            return nil
        }
    }
}



