//
//  ShakeButtonView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/20.
//
import SwiftUI
import UIKit
import CoreMotion

final class MotionTilt: ObservableObject {
    private let mgr = CMMotionManager()
    @Published var x: CGFloat = 0   // 左右（ロール）
    @Published var y: CGFloat = 0   // 上下（ピッチ）
    func start() {
        guard mgr.isDeviceMotionAvailable else { return }
        mgr.deviceMotionUpdateInterval = 1.0 / 60.0
        mgr.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let d = data else { return }
            // 弱めに正規化（酔い防止）
            self?.x = .init(max(-1, min(1, d.attitude.roll  * 0.6)))
            self?.y = .init(max(-1, min(1, d.attitude.pitch * 0.6)))
        }
    }
    func stop() { mgr.stopDeviceMotionUpdates() }
}

/// 水面の“立体波紋”アニメ：陰影・グロー・層・薄い屈折
struct WaterRipple3DView: View {
    var color: Color = .blue
    var isAnimating: Bool = true
    var tiltX: CGFloat = 0     // MotionTilt.x を渡す
    var tiltY: CGFloat = 0     // MotionTilt.y を渡す

    private let rippleCount = 5
    private let period: Double = 1.5
    private let maxScale: CGFloat = 1.75
    private let minScale: CGFloat = 0.55

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                guard isAnimating else { return }
                let c = CGPoint(x: size.width/2, y: size.height/2)

                let lx = CGFloat(0.25 + tiltX * 0.10)
                let ly = CGFloat(-0.6  + tiltY * 0.10)

                // 背景ビネットは通常のコンテキストでOK
                let vignette = Gradient(stops: [
                    .init(color: .black.opacity(0.08), location: 0.0),
                    .init(color: .clear,             location: 0.9)
                ])
                ctx.fill(
                    Path(ellipseIn: CGRect(origin: .zero, size: size)),
                    with: .radialGradient(Gradient(colors: vignette.stops.map{$0.color}),
                                          center: c, startRadius: 0, endRadius: min(size.width, size.height)/1.1)
                )

                // ✅ ここから“影付きのレイヤ”に描く
                ctx.drawLayer { layer in
                    // ← 影は layer に付ける
                    layer.addFilter(.shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 8))

                    for i in 0..<rippleCount {
                        let phase   = (t / period + Double(i) / Double(rippleCount)).truncatingRemainder(dividingBy: 1.0)
                        let scale   = minScale + (maxScale - minScale) * phase
                        let opacity = max(0.0, 1.0 - phase)
                        let line    = 4.0 + 2.0 * phase

                        let r = min(size.width, size.height) * 0.32 * scale
                        var ring = Path()
                        ring.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r*2, height: r*2))

                        // 1) ベース線
                        layer.stroke(ring, with: .color(color.opacity(0.28 * opacity)), lineWidth: line)

                        // 2) 片側ハイライト（conicGradient は Gradient を直接渡す）
                        let highlightGrad  = Gradient(colors: [.white.opacity(0.20 * opacity), .clear, .clear, .clear])
                        let highlightAngle = Angle(degrees: Double(atan2(ly, lx)) * 180 / .pi)
                        layer.stroke(
                            ring,
                            with: .conicGradient(highlightGrad, center: c, angle: highlightAngle),
                            lineWidth: line * 0.7
                        )

                        // 3) 外側グロー
                        layer.stroke(ring, with: .color(color.opacity(0.08 * opacity)), lineWidth: line * 1.8)

                        // 4) 薄い内側屈折
                        let inner = Path(ellipseIn: CGRect(x: c.x - r*0.96, y: c.y - r*0.96, width: r*1.92, height: r*1.92))
                        layer.stroke(inner, with: .color(.white.opacity(0.06 * opacity)), lineWidth: line * 0.5)
                    }
                }

                // ごく薄いノイズ（通常のコンテキストでOK）
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.02)))
            }
            .blur(radius: 0.8)
            .blendMode(.plusLighter)
        }
    }
}

struct ShakeButtonView: View {
    
    private enum SearchState { case idle, searching, found, notFound }

    @State private var searchState: SearchState = .idle
    @State private var searchTimeoutTimer: Timer? = nil
    
    @State private var animate = false
    @State private var foundFriend = false
    @State private var showBanner = false
    @State private var navigateToFriend = false
    
    @State private var foundFriendName = "Emily"
    @State private var foundFriendImage = "sample_icon1" // アイコン名
    
    @State private var bannerTimer: Timer? = nil

    @State private var receivedUser: CurrentUser? = nil
    
    @ObservedObject var profileManager = ProfileManager.shared

    @State private var finalIcon: String = "profile_startImage" // 初期値を使っておく
    @StateObject private var tilt = MotionTilt()
    
    let dummyUser = CurrentUser(
        uuid: "dummy",
        name: "Dummy",
        description: "",
        icon: "profile_startImage",
        link: "",
        challengeStatus: 0,
        recentPhotos: []
    )

    // このビューを閉じるためのEnvironmentプロパティ
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationStack {
            ZStack {
                Color.blue.opacity(0.1).ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    // 中央アニメーション
                    ZStack {
                        FullScreenRippleBackground(color: .blue, animate: animate, tilt: tilt)
                        
                        // ✅ 追加：左側の扇形スキャン（装飾のみ）
//                        FanRadarPeopleView(iconColor: .blue, tilt: tilt)
//                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
//                            .padding(.leading, 6)
                        // “床”の楕円影（カードが浮いて見える）
                        Ellipse()
                            .fill(Color.black.opacity(0.45))
                            .frame(width: 260, height: 26)
                            .blur(radius: 10)
                            .offset(y: 62)


                        // センターの“ガラス”ボタン（既存アイコンのまま）
//                        Circle()
//                            .fill(.ultraThinMaterial)
//                            .frame(width: 86, height: 86)
//                            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
//                            .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
//                            .overlay(
//                                Image(systemName: "person.2.wave.2.fill") // ← 既存アイコンがあれば差し替え不要
//                                    .resizable().scaledToFit()
//                                    .frame(width: 46, height: 34)
//                                    .foregroundStyle(.blue)
//                            )
                    }
                    .drawingGroup()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)


                    // 状態テキスト
                    // 旧: Text(foundFriend ? "Friend Found!" : "Connecting...")
                    VStack(spacing: 8) {
                        switch searchState {
                        case .idle:
                            Text("待機中").font(.title3).foregroundColor(.secondary)

                        case .searching:
                            VStack(spacing: 6) {
                                ProgressView()
                                Text("友達を探しています…")
                                    .font(.title3).fontWeight(.semibold).foregroundColor(.blue)
                            }

                        case .found:
                            Text("友達が見つかりました！")
                                .font(.title3).fontWeight(.semibold).foregroundColor(.blue)

                        case .notFound:
                            VStack(spacing: 10) {
                                Text("友達が見つかりません！")
                                    .font(.title3).fontWeight(.semibold).foregroundColor(.red)
                                Button {
                                    beginDiscovery()
                                    handleShake()
                                } label: {
                                    Text("もう一度探す")
                                        .font(.subheadline).fontWeight(.bold)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Color.blue).foregroundColor(.white).cornerRadius(10)
                                }
                            }
                        }
                    }
                    .animation(.easeInOut, value: searchState)


                    Spacer()

                    // シェイクボタン
                    Button(action: {
//                        guard !MultipeerManager.shared.isCommunicating else {
//                            print("[ShakeButtonView] ⚠️ 通信中。ボタン無効。")
//                            return
//                        }
//                        
//                        // 新たに追加
//                        MultipeerManager.shared.isCommunicating = true
//                        print("[ShakeButtonView] → isCommunicating = true 設定")
//                        
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                            MultipeerManager.shared.isCommunicating = false
//                            print("[ShakeButtonView] → isCommunicating = false 設定")
//                        }
//                        
//                        animate = true
//                        foundFriend = false
//                        showBanner = false
//
//                        print("[ShakeButtonView] ボタン押下 → 通信開始")
//                        MultipeerManager.shared.detectHandshake()
                        guard !MultipeerManager.shared.isCommunicating else {
                            print("[ShakeButtonView] ⚠️ 通信中。ボタン無効。")
                            return
                        }
                        beginDiscovery()
                        handleShake()
                        print("[ShakeButtonView] ボタン押下 → 探索開始")
//                        MultipeerManager.shared.detectHandshake()
                    }) {
                        Text("Shake to Connect")
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    .padding(.horizontal)
                }

                // 上部から降りるバナー風
                if showBanner {
                    VStack {
                        Button(action: {
                            if receivedUser != nil {
                                navigateToFriend = true // FriendFoundViewへ遷移
                            } else {
                                print("[ShakeButtonView] ⚠️ バナータップされたが receivedUser が nil")
                            }
                        }) {
                            HStack {
                                Image(systemName: "hands.sparkles.fill")
                                    .foregroundColor(.blue)
                                Text("Connected with \(foundFriendName)!")
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 3)
                            .padding()
                        }

                        Spacer()
                    }
                    .transition(.move(edge: .top))
                }

                // NavigationLink
                NavigationLink(
                    destination: FriendFoundView(receivedUser: receivedUser ?? dummyUser),
                    isActive: $navigateToFriend
                ) {
                    EmptyView()
                }
                .onDisappear { // FriendFoundViewが閉じられたら
                    // presentationMode.wrappedValue.dismiss() // この行を削除またはコメントアウト
                    print("[ShakeButtonView] FriendFoundViewが閉じられました。")
                }
            }
            .onAppear {
                animate = true
                foundFriend = false
                showBanner = false
                navigateToFriend = false
                receivedUser = nil
                foundFriendName = ""
                foundFriendImage = "profile_startImage"
                
                // ✅ 通信状態を完全に初期化
                MultipeerManager.shared.stop()
                MultipeerManager.shared.isHandshakeDetected = false
                MultipeerManager.shared.isCommunicating = false
                
                print("[ShakeButtonView] 表示開始 & 状態初期化")

                // onAppear 内の onReceiveUser クロージャを次で置き換え
                MultipeerManager.shared.onReceiveUser = { user in
                    DispatchQueue.main.async {   // ✅ 追加
                        print("[ShakeButtonView] データ受信: \(user.uuid)")
                        foundFriendName = user.name
                        foundFriendImage = user.icon
                        receivedUser = user
                        foundFriend = true
                        searchTimeoutTimer?.invalidate()
                        searchState = .found
                        hapticNotify(.success)
                        withAnimation { showBanner = true }
                        MultipeerManager.shared.isCommunicating = false
                    }
                }
                searchState = .idle
            }

            .onDisappear {
                print("[ShakeButtonView] 表示終了 → 通信停止")
                bannerTimer?.invalidate()
                MultipeerManager.shared.stop()
                MultipeerManager.shared.onReceiveUser = nil
                searchTimeoutTimer?.invalidate()
            }
            .onChange(of: MultipeerManager.shared.isHandshakeDetected) { newValue in
                if newValue {
                    handleShake()
                }
            }
            .onChange(of: showBanner) { newValue in
                if newValue {
                    // タイマーを設定
                    bannerTimer?.invalidate()
                    bannerTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                        // ✅ すでに遷移が始まっている場合は処理を中断
                        guard !navigateToFriend else {
                            print("[ShakeButtonView] ✅ ナビゲーション中なのでタイマーリセットなし")
                            return
                        }

                        if showBanner {
                            withAnimation {
                                showBanner = false
                            }
                            foundFriend = false
                            receivedUser = nil
                            print("[ShakeButtonView] ⏱️ バナータイムアウト → 通信切断＆再探索")

                            MultipeerManager.shared.stop()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                MultipeerManager.shared.detectHandshake()
                            }
                        }
                    }
                } else {
                    bannerTimer?.invalidate()
                }
            }
        }
    }
    
    private func hapticNotify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(type)
    }
    
    func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    // handleShake() を次の内容に“置き換え”
    func handleShake() {
        print("[ShakeButtonView] シェイク検知 → 通信処理")
        // すでに検索中でなければ開始
        if searchState != .searching {
            beginDiscovery()
        }
        MultipeerManager.shared.startAdvertising()
        MultipeerManager.shared.startBrowsing()

        if let data = try? JSONEncoder().encode(profileManager.currentUser) {
            MultipeerManager.shared.send(data: data)
            print("[ShakeButtonView] データ送信: \(profileManager.currentUser.uuid)")
        }
    }

    
//    func handleShake() {
//        print("[ShakeButtonView] シェイク検知 → 通信処理")
//        MultipeerManager.shared.startAdvertising()
//        MultipeerManager.shared.startBrowsing()
//
//        if let data = try? JSONEncoder().encode(profileManager.currentUser) {
//            MultipeerManager.shared.send(data: data)
//            print("[ShakeButtonView] データ送信: \(profileManager.currentUser.uuid)")
//        }
//    }
    // View 内のメソッド群の末尾あたりに追加
    private func beginDiscovery() {
        // UI初期化
        animate = true
        foundFriend = false
        showBanner = false
        navigateToFriend = false
        receivedUser = nil
        foundFriendName = ""
        foundFriendImage = "profile_startImage"

        // 通信初期化
        MultipeerManager.shared.stop()
        MultipeerManager.shared.isHandshakeDetected = false
        MultipeerManager.shared.isCommunicating = true

        // 状態：検索中
        searchState = .searching
        hapticNotify(.warning) // 🔔 開始タイミングのバイブ

        // タイムアウト（例：8秒）
        searchTimeoutTimer?.invalidate()
        searchTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
            if receivedUser == nil && searchState == .searching {
                failDiscovery()
            }
        }
    }

    private func failDiscovery() {
        MultipeerManager.shared.stop()
        MultipeerManager.shared.isCommunicating = false

        withAnimation {
            showBanner = false
            foundFriend = false
            searchState = .notFound
        }
        hapticNotify(.error) // 🔔 未発見のバイブ
    }

}

/// 画面いっぱいに“水面の波紋”を敷く背景（タップ操作を邪魔しない）
struct FullScreenRippleBackground: View {
    var color: Color = .blue
    var animate: Bool = true
    @ObservedObject var tilt: MotionTilt

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1) 深いビネット（上下端を沈ませて奥行き）
                RadialGradient(
                    colors: [.black, .black.opacity(0.6), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(geo.size.width, geo.size.height) * 0.9
                )
                .opacity(0.55)
                .ignoresSafeArea()

                // 2) 全面の波紋（画面対角より少し大きく）
               WaterRipple3DView(
                   color: color,
                   isAnimating: animate,
                   tiltX: tilt.x,
                   tiltY: tilt.y
               )
               .frame(
                   width: max(geo.size.width, geo.size.height) * 1.2,
                   height: max(geo.size.width, geo.size.height) * 1.2
               )
               // 視覚中心のズレ防止：perspective を弱める/0に
               .rotation3DEffect(.degrees(3 * Double(tilt.y)),
                                 axis: (x: 1, y: 0, z: 0),
                                 perspective: 0.25)
               .rotation3DEffect(.degrees(-5 * Double(tilt.x)),
                                 axis: (x: 0, y: 1, z: 0),
                                 perspective: 0.0)
               // 傾きに応じた微小補正（見た目の中心をキープ）
               .offset(x: -tilt.x * 6, y: tilt.y * 4)
               .blendMode(.plusLighter)

                // 3) 下側の“水面下の影”を強く（立体感）
                LinearGradient(
                    colors: [.black.opacity(0.7), .black.opacity(0.25), .clear],
                    startPoint: .bottom, endPoint: .center
                )
                .ignoresSafeArea()
                .opacity(0.9)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false) // ← 背景なのでタップは透過
    }
}

/// 左側に“人アイコン”が扇形に並んでスキャンしているように見せる装飾
struct FanRadarPeopleView: View {
    var iconColor: Color = .blue
    var count: Int = 7              // 並べる人数
    var radius: CGFloat = 170       // 扇の半径
    var startDeg: Double = 110      // 左上（反時計回りスタート）
    var endDeg: Double = 250        // 左下（反時計回りエンド）
    @ObservedObject var tilt: MotionTilt

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                // 扇の中心は画面の“左中央”より少し内側
                let cx: CGFloat = 200
                let cy: CGFloat = geo.size.height / 2

                ZStack(alignment: .leading) {
                    ForEach(0..<count, id: \.self) { i in
                        let p = Double(i) / Double(max(count - 1, 1))
                        let deg = startDeg + (endDeg - startDeg) * p
                        let rad = deg * .pi / 180

                        let r = radius + CGFloat(sin(t * 0.7 + Double(i) * 0.25)) * 2
                        let x = cx + r * cos(rad) + tilt.x * 6
                        let y = cy + r * sin(rad) + tilt.y * 4

                        let phase = 0.5 + 0.5 * sin(t * 2.0 + Double(i) * 0.6)
                        let scale = 0.9 + 0.15 * CGFloat(phase)
                        let op = 0.35 + 0.55 * CGFloat(phase)

                        ZStack {
                            Circle()
                                .fill(iconColor.opacity(0.18))
                                .frame(width: 38, height: 38)
                                .blur(radius: 6)

                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 34, height: 34)
                                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)

                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundStyle(iconColor)
                                .opacity(op)
                        }
                        .scaleEffect(scale)
                        .position(x: x, y: y)
                        .allowsHitTesting(false)
                    }
                }
                .blendMode(.plusLighter)
            }
        }
        .allowsHitTesting(false)
    }
}
