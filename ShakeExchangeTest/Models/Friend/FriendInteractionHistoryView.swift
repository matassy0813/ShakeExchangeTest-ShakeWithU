//
//  FriendInteractionHistoryView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/08/30.
//
import CoreLocation
import MapKit
import SwiftUI
import UIKit // UIImage のために必要
import FirebaseFirestore // DocumentSnapshotのために追加


struct InteractionRowView: View {
    let item: FriendInteraction
    @State private var place: String = "読み込み中…"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(formattedDate(item.timestamp))
                    .font(.subheadline).bold()
                Spacer()
                if let kind = item.kind, !kind.isEmpty {
                    Text(kindLabel(kind))
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            Text(place)
                .font(.subheadline)

            if let note = item.note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundColor(.gray)
            }

            HStack(spacing: 12) {
                Button {
                    openInMaps(lat: item.latitude, lon: item.longitude)
                } label: {
                    Label("マップで開く", systemImage: "map")
                }
                .buttonStyle(.bordered)

                Button {
                    UIPasteboard.general.string = String(format: "%.6f, %.6f", item.latitude, item.longitude)
                } label: {
                    Label("座標コピー", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
            .font(.footnote)
        }
        .task {
            // 逆ジオコーディング
            let name = await reverseGeocode(lat: item.latitude, lon: item.longitude)
            await MainActor.run { self.place = name }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月d日"
        return f.string(from: date)
    }

    private func kindLabel(_ kind: String) -> String {
        switch kind {
        case "shake": return "握手交換"
        case "photo": return "写真"
        case "chat":  return "会話"
        default:      return kind
        }
    }

    private func openInMaps(lat: Double, lon: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = "交流地点"
        item.openInMaps(launchOptions: [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinate),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        ])
    }

    private func reverseGeocode(lat: Double, lon: Double) async -> String {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: lat, longitude: lon)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let p = placemarks.first {
                // 市区町村 + 地名レベルで簡潔に
                let comps = [p.administrativeArea, p.locality, p.subLocality, p.name].compactMap { $0 }.filter { !$0.isEmpty }
                if !comps.isEmpty { return comps.joined(separator: " ") }
            }
        } catch { /* 無視してフォールバック */ }
        return String(format: "%.6f, %.6f", lat, lon)
    }
}
