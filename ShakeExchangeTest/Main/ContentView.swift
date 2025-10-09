//
//  ContentView.swift
//  ShakeExchangeTest
//
//  Created by 俣江悠聖 on 2025/05/19.
//
import SwiftUI
import UIKit

// MARK: - 画面ID
enum AppScreen: Int, CaseIterable {
    case home, album, shake, friends, network, profile, ranking
}

enum DockPlacement: String, CaseIterable {
    case bottom   // 画面下の横ドック
    case right    // 画面右の縦レール
    // 必要なら .left も後で追加できます
}


// MARK: - メニュー項目
struct SpaceItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let color: Color
    let screen: AppScreen
    let bgImageName: String?
    let cardImageName: String?
}

// MARK: - 3Dユーティリティ
struct Depth: GeometryEffect {
    var z: CGFloat
    var animatableData: CGFloat {
        get { z }
        set { z = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        var t = CATransform3DIdentity
        t.m34 = -1/600
        t = CATransform3DTranslate(t, 0, 0, z)
        return ProjectionTransform(t)
    }
}
struct Perspective: ViewModifier {
    func body(content: Content) -> some View {
        content.rotation3DEffect(.degrees(0), axis: (x: 0, y: 0, z: 0), perspective: 0.7)
    }
}

// MARK: - 3Dカード
struct SpaceCard: View {
    let item: SpaceItem
    var isFocused: Bool
    var tilt: CGSize
    var index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let yawBase: Double   = isFocused ? 0 : (index.isMultiple(of: 2) ? -12 : 12)
        let yawDrag: Double   = max(-14, min(14, Double(tilt.width / 6)))
        let pitchBase: Double = -4
        let pitchDrag: Double = max(-8,  min(8,  Double(-tilt.height / 10)))
        let zDepth: CGFloat   = isFocused ? 0 : -80

        // ===== ここからカード面 =====
        Group {
            if let name = item.cardImageName, let ui = UIImage(named: name) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 220, height: 280)
                    .clipped()
                    .cornerRadius(20)
                    // 読みやすさのために薄い縁＆内側シャドウ（任意）
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
                    .overlay(LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.18)],
                                            startPoint: .top, endPoint: .bottom)
                                .clipShape(RoundedRectangle(cornerRadius: 20)))
            } else {
                // フォールバック（画像が無い場合）
                RoundedRectangle(cornerRadius: 20)
                    .fill(item.color.gradient)
                    .frame(width: 220, height: 280)
            }
        }
        .shadow(radius: isFocused ? 18 : 10, y: isFocused ? 14 : 6)
        .modifier(Perspective())
        .rotation3DEffect(.degrees(pitchBase + pitchDrag), axis: (x: 1, y: 0, z: 0))
        .rotation3DEffect(.degrees(yawBase + yawDrag),   axis: (x: 0, y: 1, z: 0))
        .modifier(Depth(z: zDepth))
        .offset(x: (isFocused ? 0.02 : 0.05) * tilt.width)
        .scaleEffect(isFocused ? 1.02 : 0.92)
        .animation(reduceMotion ? .default : .easeInOut(duration: 0.55), value: isFocused)
    }
}


// === 背景用ヘルパー（追加） ===
extension Color {
    func lighten(_ amount: CGFloat = 0.18) -> Color { self._adjust(brightnessDelta: amount,  saturationDelta: 0) }
    func darken (_ amount: CGFloat = 0.22) -> Color { self._adjust(brightnessDelta: -amount, saturationDelta: 0) }
    private func _adjust(brightnessDelta: CGFloat, saturationDelta: CGFloat) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return Color(UIColor(hue: h, saturation: max(0,min(1,s+saturationDelta)),
                             brightness: max(0,min(1,b+brightnessDelta)), alpha: a))
    }
}

@ViewBuilder
func vrBackground(for item: SpaceItem?, parallax: CGSize) -> some View {
    let base = item?.color ?? .blue

    GeometryReader { geo in
        let w = geo.size.width
        let h = geo.size.height

        ZStack {
            // --- 奥の壁（背景画像） ---
            if let name = item?.bgImageName, let uiImg = UIImage(named: name) {
                // 画面より一回り小さく＆パララックス弱め＝遠く見える
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w * 0.88, height: h * 0.78)   // ← 小さくする
                    .clipped()
                    .cornerRadius(36)
                    .shadow(color: .black.opacity(0.25), radius: 20, y: 12) // 壁の落ち影
                    .rotation3DEffect(.degrees(-5), axis: (x: 1, y: 0, z: 0)) // わずかに手前床へ倒す
                    .offset(
                        x: parallax.width / 40,   // ← パララックス弱い（遠い）
                        y: parallax.height / 50
                    )
                    .blur(radius: 6) // 遠景の軽いボケ
                    .overlay(
                        // 端を少し暗くして“壁の縁”を出す
                        LinearGradient(
                            colors: [.black.opacity(0.18), .clear, .black.opacity(0.28)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .blendMode(.multiply)
                    )
                    .position(x: w/2, y: h*0.47) // 少し上寄せ＝床が手前にある感じ
                    .allowsHitTesting(false)
            } else {
                // 画像なしフォールバック（控えめなグラデ）
                LinearGradient(colors: [base.opacity(0.4), .black.opacity(0.8)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            }

            // --- グリッド（薄く、壁の上） ---
            Image(systemName: "square.grid.3x3.fill")
                .resizable().scaledToFit()
                .frame(width: w * 0.95)
                .foregroundStyle(base.opacity(0.06))
                .offset(x: parallax.width/18, y: parallax.height/20) // 壁より少し強めの視差
                .allowsHitTesting(false)

            // --- 半透明の“奥の壁パネル” ---
            RoundedRectangle(cornerRadius: 42)
                .fill(.white.opacity(0.05))
                .frame(width: w * 0.84, height: h * 0.66)
                .blur(radius: 14)
                .offset(y: 24)
                .rotation3DEffect(.degrees(-6), axis: (x: 1, y: 0, z: 0))
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}


// MARK: - VR風メニュー（ページング）
struct SpacePickerView: View {
    let items: [SpaceItem]
    var onSelect: (SpaceItem) -> Void

    @State private var selected: SpaceItem?
    @State private var drag: CGSize = .zero
    @State private var cameraY: CGFloat = 0
    @State private var page: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // ✅ ここを置き換え：動的背景に
            let currentItem = (items.indices.contains(page) ? items[page] : nil)
            vrBackground(for: currentItem, parallax: drag)

            // ⬇︎ ここから下は既存の TabView/カード群 そのままでOK
            TabView(selection: $page) {
                ForEach(items.indices, id: \.self) { i in
                    let item = items[i]
                    let isFocused = (selected == nil ? i == page : selected == item)

                    SpaceCard(item: item, isFocused: isFocused, tilt: drag, index: i)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(i)
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(reduceMotion ? .default : .spring(response: 0.6, dampingFraction: 0.85)) {
                                selected = item
                            }
                            withAnimation(.easeInOut(duration: 0.5)) { cameraY = -20 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                                onSelect(item)
                            }
                        }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            .offset(y: cameraY)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag = $0.translation }
                    .onEnded { _ in withAnimation(.easeOut(duration: 0.3)) { drag = .zero } }
            )

            // （下部ガイドなどはそのまま）
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Image(systemName: "hand.draw.fill")
                        .foregroundStyle(.white.opacity(0.85))
                    Text("左右にスワイプして選ぶ。タップで決定")
                        .font(.callout).foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(true)
    }
}

// MARK: - ローディング
struct LoadingView: View {
    @State private var isAnimating = false
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Circle()
                    .trim(from: 0, to: 0.8)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.purple, .blue, .pink]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
                    .onAppear { isAnimating = true }
                Text("Loading...")
                    .foregroundColor(.white)
                    .font(.caption)
            }
        }
    }
}

/// iOS26のLiquid Glassを用いた下部メニュー
struct GlassBottomMenu: View {
    @Binding var current: AppScreen
    @Environment(\.accessibilityReduceTransparency) private var reduceTrans
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Item: Identifiable {
        let id = UUID()
        let screen: AppScreen
        let label: String
        let systemImage: String
    }

    private let items: [Item] = [
        .init(screen: .home,    label: "Feed",    systemImage: "house.fill"),
        .init(screen: .shake,   label: "Shake",   systemImage: "dot.radiowaves.left.and.right"),
        .init(screen: .friends, label: "Friends", systemImage: "person.2.fill"),
        .init(screen: .album,   label: "Album",   systemImage: "photo.on.rectangle"),
        .init(screen: .network, label: "Network", systemImage: "point.3.connected.trianglepath.dotted"),
        .init(screen: .ranking, label: "Ranking", systemImage: "rosette"),
        .init(screen: .profile, label: "Me",      systemImage: "person.crop.circle.fill")
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items) { item in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(reduceMotion ? .default : .spring(response: 0.45, dampingFraction: 0.88)) {
                        current = item.screen
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                        Text(item.label).font(.caption2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .padding(.vertical, 8)
                    .contentTransition(.symbolEffect) // iOS26の新しい遷移（任意）
                }
                .buttonStyle(.plain)
                .foregroundStyle(current == item.screen ? .primary : .secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(background) // ← Liquid Glassを適用
        .clipShape(Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .shadow(radius: 18, y: 8)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var background: some View {
        if #available(iOS 26, *), !reduceTrans {
            // Apple推奨：システムに効果は任せる
            GlassEffectContainer {
                Capsule().glassEffect()
            }
        } else {
            Capsule().fill(.ultraThinMaterial)
        }
    }
}

struct GlassSideMenu: View {
    @Binding var current: AppScreen
    @Environment(\.accessibilityReduceTransparency) private var reduceTrans
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Item: Identifiable {
        let id = UUID()
        let screen: AppScreen
        let label: String
        let systemImage: String
    }
    private let items: [Item] = [
        .init(screen: .home,    label: "Feed",    systemImage: "house.fill"),
        .init(screen: .shake,   label: "Shake",   systemImage: "dot.radiowaves.left.and.right"),
        .init(screen: .friends, label: "Friends", systemImage: "person.2.fill"),
        .init(screen: .album,   label: "Album",   systemImage: "photo.on.rectangle"),
        .init(screen: .network, label: "Network", systemImage: "point.3.connected.trianglepath.dotted"),
        .init(screen: .ranking, label: "Ranking", systemImage: "rosette"),
        .init(screen: .profile, label: "Me",      systemImage: "person.crop.circle.fill")
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(items) { item in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(reduceMotion ? .default : .spring(response: 0.45, dampingFraction: 0.88)) {
                        current = item.screen
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                        Text(item.label).font(.caption2)
                    }
                    .frame(minWidth: 56, minHeight: 52)
                    .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(current == item.screen ? .primary : .secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(sideBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(radius: 18, x: 8, y: 0)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var sideBackground: some View {
        if #available(iOS 26, *), !reduceTrans {
            GlassEffectContainer { RoundedRectangle(cornerRadius: 22).glassEffect() }
        } else {
            RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial)
        }
    }
}

private extension Comparable {
    func clamped(to r: ClosedRange<Self>) -> Self { min(max(self, r.lowerBound), r.upperBound) }
}

struct DraggableAdaptiveDock: View {
    @Binding var current: AppScreen
    @Namespace private var dockNS

    @State private var placement: DockPlacement = .bottom
    private func setPlacement(_ p: DockPlacement) { placement = p }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                dockContainer // 👈 常にひとつだけ
                    .matchedGeometryEffect(id: "dock", in: dockNS)
                    .padding(placement == .bottom ? .bottom : .trailing, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignmentForPlacement)
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                switch placement {
                                case .bottom:
                                    if value.translation.width > w * 0.2 {
                                        withAnimation(.interpolatingSpring(stiffness: 240, damping: 28)) {
                                            setPlacement(.right)
                                        }
                                    }
                                case .right:
                                    if value.translation.height > h * 0.2 {
                                        withAnimation(.interpolatingSpring(stiffness: 240, damping: 28)) {
                                            setPlacement(.bottom)
                                        }
                                    }
                                }
                            }
                    )
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // === コンテナ ===
    private var dockContainer: some View {
        Group {
            if placement == .bottom {
                GlassBottomMenu(current: $current) // 横並び
            } else {
                GlassSideMenu(current: $current)   // 縦並び
            }
        }
    }

    // === 配置位置を決める ===
    private var alignmentForPlacement: Alignment {
        switch placement {
        case .bottom: return .bottom
        case .right:  return .trailing
        }
    }
}




// MARK: - ニュルッと移動用 Modifier
private struct NyuruTransition: ViewModifier {
    enum Role { case bottom, right }
    let role: Role
    let drag: CGSize
    let containerSize: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let triggerPct: CGFloat = 0.23
    private let rubberLimit: CGFloat = 120
    private let tiltDeg: CGFloat = 6
    private let liftScale: CGFloat = 0.02
    private let shadowMax: CGFloat = 20

    func body(content: Content) -> some View {
        let w = containerSize.width
        let h = containerSize.height

        let progress: CGFloat = {
            switch role {
            case .bottom:
                let p = rubberBand(max(0, drag.width)) / (w * triggerPct)
                return min(1, max(0, p))
            case .right:
                let p = rubberBand(max(0, drag.height)) / (h * triggerPct)
                return min(1, max(0, p))
            }
        }()

        let offsetX: CGFloat = role == .bottom ? progress * 22 : 0
        let offsetY: CGFloat = role == .right  ? progress * 22 : 0
        let tilt: Angle = .degrees(Double(progress * tiltDeg))
        let scale: CGFloat = 1 + (reduceMotion ? 0 : progress * liftScale)
        let shadow: CGFloat = progress * shadowMax

        return content
            .offset(x: offsetX, y: offsetY)
            .rotationEffect(role == .bottom ? tilt : .degrees(0))
            .rotationEffect(role == .right  ? tilt : .degrees(0))
            .scaleEffect(scale)
            .shadow(color: .black.opacity(0.25), radius: shadow, x: 0, y: role == .right ? 8 : 4)
            .animation(
                reduceMotion ? nil : .interpolatingSpring(stiffness: 240, damping: 28),
                value: progress
            )
    }

    private func rubberBand(_ x: CGFloat) -> CGFloat {
        let s = abs(x), sign: CGFloat = x < 0 ? -1 : 1
        let y = (s * rubberLimit) / (s + rubberLimit)
        return y * sign
    }
}


// MARK: - メイン（TabView廃止版）
struct ContentView: View {
    @ObservedObject var authManager = AuthManager.shared
    @State private var isFeedReady = false
    @State private var animateTransition = false
    @AppStorage("useFab") private var useFab: Bool = false

    // 現在の画面
    @State private var currentScreen: AppScreen = .home
    // メニュー表示
    @State private var showPicker = false

    var items: [SpaceItem] {
        [
            // 2枚目の画像（MAIN）→ アセット名 "circle" として登録されている想定
            .init(title: "Feed",    subtitle: "最新の投稿",  color: .blue,   screen: .home,
                  bgImageName: "MainMenuIcon",               cardImageName: "MainMenuIcon"),

            // Album.png
            .init(title: "Album",   subtitle: "写真・動画",  color: .purple, screen: .album,
                  bgImageName: "AlbumMenuIcon",               cardImageName: "AlbumMenuIcon"),

            // ShakeMenuAikon.png（※アセット名はそのまま or "ShakeMenuAikon"）
            .init(title: "Shake",   subtitle: "ふるって発見", color: .indigo, screen: .shake,
                  bgImageName: "ShakeMenuIcon",               cardImageName: "ShakeMenuIcon"),

            // Friends.png
            .init(title: "Friends", subtitle: "つながり",    color: .teal,   screen: .friends,
                  bgImageName: "FriendsMenuIcon",               cardImageName: "FriendsMenuIcon"),

            // network.png（小文字名のまま登録していれば "network"）
            .init(title: "Network", subtitle: "関係を俯瞰",  color: .green,  screen: .network,
                  bgImageName: "NetworkMenuIcon",               cardImageName: "NetworkMenuIcon"),

            // Profile.png
            .init(title: "Profile", subtitle: "あなたの情報", color: .orange, screen: .profile,
                  bgImageName: "ProfileMenuIcon",               cardImageName: "ProfileMenuIcon"),

            // Ranking.png
            .init(title: "Ranking", subtitle: "直近の勢い",  color: .pink,   screen: .ranking,
                  bgImageName: "RankingMenuIcon",               cardImageName: "RankingMenuIcon")
        ]
    }


    var body: some View {
        if authManager.isAuthenticated && authManager.hasAgreedToTerms {
            ZStack {
                // 表示中の画面を切り替え
                Group {
                    switch currentScreen {
                    case .home:    HomeView()
                    case .album:   AlbumMainView()
                    case .shake:   ShakeButtonView()
                    case .friends: FriendMainView()
                    case .network: SocialNetworkView()
                    case .profile: ProfileView()
                    case .ranking: FriendRecentRankingView().environmentObject(FriendManager.shared)
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                    removal:   .opacity
                ))
                .animation(.easeOut(duration: 0.35), value: currentScreen)
                .opacity(isFeedReady ? 1 : 0)
                .scaleEffect(isFeedReady ? 1 : 0.98)
                .onAppear { animateTransition = true }

                // 右下のメニューボタン（任意・サブ操作）
                if isFeedReady, useFab {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                showPicker = true  // 旧フルスクリーンのVR風メニューを起動
                            } label: {
                                Label("Menu", systemImage: "rectangle.3.group.bubble.left")
                                    .labelStyle(.iconOnly)
                                    .font(.system(size: 18, weight: .semibold))
                                    .padding(14)
                                    // iOS26なら軽いガラス、未満はMaterial
                                    .background(
                                        Group {
                                            if #available(iOS 26, *) {
                                                Circle().glassEffect()
                                            } else {
                                                Circle().fill(.ultraThinMaterial)
                                            }
                                        }
                                    )
                            }
                            .padding(.trailing, 18)
                            // 下部Glassメニューの高さぶんだけ持ち上げて重なり回避
                            .padding(.bottom, 96)
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .transition(.opacity)
                }
                DraggableAdaptiveDock(current: $currentScreen)
                // ローディング
                if !isFeedReady {
                    LoadingView()
                }
            }
            .background(Color.black.ignoresSafeArea())
            // 初回だけ自動でメニュー表示
            .onAppear {
                Task {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    isFeedReady = true
                    if !UserDefaults.standard.bool(forKey: "didShowVRPickerOnce_NoTab") {
                        showPicker = true
                        UserDefaults.standard.set(true, forKey: "didShowVRPickerOnce_NoTab")
                    }
                }
            }
            // メニュー（フルスクリーン）
            .fullScreenCover(isPresented: $showPicker) {
                SpacePickerView(items: items) { item in
                    currentScreen = item.screen
                    showPicker = false
                }
            }

        } else if authManager.isAuthenticated && !authManager.hasAgreedToTerms {
            TermsAndPrivacyConsentView(isPresented: .constant(true))
        } else {
            AuthView()
        }
    }
}

#Preview {
    ContentView()
}
