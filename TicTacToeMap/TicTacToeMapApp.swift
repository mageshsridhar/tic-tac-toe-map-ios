import SwiftUI
import UIKit

@main
struct TicTacToeMapApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var model = GameModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// "light", "dark", or "" to follow the system until the toggle is used.
    @AppStorage("ttt-theme") private var savedTheme = ""
    @State private var isDark = ContentView.startsDark()
    // The bubble theme switch: a snapshot of the old theme with a growing hole centred on the toggle.
    @State private var oldTheme: UIImage?
    @State private var bubble: CGFloat = 0
    @State private var toggleCenter: CGPoint = .zero

    private var palette: Palette { isDark ? .dark : .light }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width >= 900 && geo.size.width > geo.size.height
            let portrait = !landscape && geo.size.width >= 700
            Group {
                if landscape {
                    // Title, game, legend and credit stack in the left column; the map takes the full height.
                    // The legend grows into the spare room, so the credit card ends level with the map.
                    HStack(alignment: .top, spacing: 22) {
                        VStack(spacing: 18) {
                            header
                            GamePanel(model: model, showsEndings: false)
                            EndingsCard(model: model, fills: true)
                            MadeByCard()
                        }
                        .frame(width: 380)
                        MapView(model: model)
                    }
                } else if portrait {
                    // Upright iPad: title, legend and credit on the left, the game on the right,
                    // and the map across the full width below.
                    VStack(spacing: 18) {
                        HStack(alignment: .top, spacing: 22) {
                            VStack(spacing: 18) {
                                header
                                // The legend grows into the column's spare room.
                                EndingsCard(model: model, fills: true)
                                MadeByCard()
                            }
                            .frame(maxHeight: .infinity)
                            GamePanel(model: model, showsEndings: false)
                                .frame(width: 380)
                                .frame(maxHeight: .infinity, alignment: .top)
                        }
                        // Both columns end at the same line: the taller one (the game card) sets the height.
                        .fixedSize(horizontal: false, vertical: true)
                        MapView(model: model)
                    }
                } else {
                    // Narrow windows (Split View, Slide Over): the game on top, the map below it.
                    VStack(spacing: 18) {
                        header.frame(width: 380)
                        GamePanel(model: model).frame(width: 380)
                        MapView(model: model)
                        MadeByCard().frame(width: 380)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .coordinateSpace(.named("root"))
        // The play board's copy flies above both panels.
        .overlay(alignment: .topLeading) {
            if let flight = model.flight { FlyingBoard(flight: flight) }
        }
        .background(palette.bg.ignoresSafeArea())
        .environment(\.palette, palette)
        .preferredColorScheme(isDark ? .dark : .light)
        // Light tap on each move, a success tap when a game is won or drawn.
        .sensoryFeedback(trigger: model.history) { old, new in
            guard new.count > old.count, let last = new.last else { return nil }
            return last.winner != nil ? .success : .impact(weight: .light)
        }
        .overlay {
            if let oldTheme {
                Image(uiImage: oldTheme)
                    .resizable()
                    .ignoresSafeArea()
                    .mask {
                        BubbleHole(center: toggleCenter, radius: bubble)
                            .fill(style: FillStyle(eoFill: true))
                            .ignoresSafeArea()
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .onAppear { model.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, v in model.reduceMotion = v }
    }

    /// The new theme grows out of the toggle as a bubble. The screen is captured in the old theme,
    /// the theme switches underneath at once, and a widening hole in the capture reveals it.
    private func switchTheme() {
        defer { savedTheme = isDark ? "dark" : "light" }
        guard !reduceMotion, let shot = Self.snapshotWindow() else {
            isDark.toggle()
            return
        }
        let size = shot.size, c = toggleCenter
        let reach = hypot(max(c.x, size.width - c.x), max(c.y, size.height - c.y))
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            oldTheme = shot
            bubble = 0
            isDark.toggle()
        }
        DispatchQueue.main.async {
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.65)) {
                bubble = reach
            } completion: {
                var quiet = Transaction()
                quiet.disablesAnimations = true
                withTransaction(quiet) { oldTheme = nil }
            }
        }
    }

    /// The app's window as an image, in window coordinates (the same as SwiftUI's global space).
    private static func snapshotWindow() -> UIImage? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        guard let window else { return nil }
        return UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Tic-Tac-Toe\nGame Map")
                .font(.ui(30, .heavy))
                .foregroundStyle(palette.fg)
                .lineSpacing(-2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Tic-Tac-Toe Game Map")
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button {
                switchTheme()
            } label: {
                // Icon-only so it fits beside the title in the 380pt column.
                Image(systemName: isDark ? "sun.max" : "moon")
                    .font(.ui(17, .semibold))
                    .foregroundStyle(palette.fg)
                    .frame(width: 44, height: 44)   // HIG minimum hit target
                    .background(palette.surface, in: Circle())
                    .overlay(Circle().strokeBorder(palette.line, lineWidth: 2))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .onGeometryChange(for: CGPoint.self) { g in
                let f = g.frame(in: .global)
                return CGPoint(x: f.midX, y: f.midY)
            } action: { toggleCenter = $0 }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .accessibilityLabel(isDark ? "Switch to light mode" : "Switch to dark mode")
        }
    }

    /// Starts from the saved choice, otherwise the system appearance.
    private static func startsDark() -> Bool {
        switch UserDefaults.standard.string(forKey: "ttt-theme") {
        case "dark": return true
        case "light": return false
        default: return UIScreen.main.traitCollection.userInterfaceStyle == .dark
        }
    }
}

/// The whole screen with a circular hole: filled even-odd, it masks the old theme away from the centre out.
struct BubbleHole: Shape {
    var center: CGPoint
    var radius: CGFloat
    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path(rect)
        p.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
        return p
    }
}

/// Credit card that fills the space under the game panel.
struct MadeByCard: View {
    @Environment(\.palette) private var palette
    @State private var textHeight: CGFloat = 56

    var body: some View {
        HStack(spacing: 14) {
            // The author's memoji, as tall as the three lines of text beside it.
            Image("Avatar")
                .resizable()
                .scaledToFit()
                .frame(height: textHeight)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("MADE BY")
                    .font(.ui(12, .heavy)).kerning(0.7)
                    .foregroundStyle(palette.muted)
                // Opens the author's portfolio in the browser.
                Link(destination: URL(string: "https://mageshsridhar.github.io")!) {
                    HStack(spacing: 4) {
                        Text("Magesh Sridhar")
                            .font(.ui(17, .bold))
                            .foregroundStyle(palette.fg)
                        Image(systemName: "arrow.up.right")
                            .font(.ui(13, .bold))
                            .foregroundStyle(palette.muted)
                    }
                    // A 44pt-tall hit area without changing the card's layout
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                    .padding(.vertical, -11)
                }
                .hoverEffect(.highlight)
                .accessibilityLabel("Magesh Sridhar's portfolio")
                .accessibilityHint("Opens in the browser")
                Text("Built with SwiftUI · Assisted by Claude Code")
                    .font(.ui(13))
                    .foregroundStyle(palette.muted)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { textHeight = $0 }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.large, style: .continuous).strokeBorder(palette.line, lineWidth: 2))
        .accessibilityElement(children: .contain)
    }
}

/// A copy of the play board that mirrors and turns to match the map's option, then flies onto it.
/// It starts looking like the play board and blends into a map board as it lands.
struct FlyingBoard: View {
    @Environment(\.palette) private var palette
    let flight: Flight

    var body: some View {
        let from = flight.from, to = flight.to
        let side = from.width
        let small = max(to.width, 1)
        let lifted = flight.oriented && !flight.landed
        ZStack {
            BoardFace(board: flight.board, side: side)
                .opacity(flight.landed ? 0 : 1)
            MiniBoard(board: flight.board, size: small, stroke: palette.focus, lineWidth: 3)
                .scaleEffect(side / small)
                .opacity(flight.landed ? 1 : 0)
        }
        .frame(width: side, height: side)
        // Mirror first (a flip like a card), then turn: the same steps as GameModel.orientation.
        .rotation3DEffect(.degrees(flight.oriented && flight.flip ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
        .rotationEffect(.degrees(flight.oriented ? 90 * Double(flight.turns) : 0))
        .scaleEffect(flight.landed ? small / side : lifted ? 0.94 : 1)
        .shadow(color: .black.opacity(flight.landed ? 0 : 0.18), radius: 18, y: 8)
        .position(flight.landed ? CGPoint(x: to.midX, y: to.midY) : CGPoint(x: from.midX, y: from.midY))
        .opacity(flight.visible ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The play board's look (rounded tiles, chunky pixel marks) at any size.
private struct BoardFace: View {
    @Environment(\.palette) private var palette
    let board: Board
    let side: CGFloat

    var body: some View {
        let u = side / (3 * 104.6 + 2 * 8)   // the play board's own proportions
        let wins = board.winningCells
        VStack(spacing: 8 * u) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 8 * u) {
                    ForEach(0..<3, id: \.self) { col in
                        let i = row * 3 + col
                        let mark = board.cells[i]
                        ZStack {
                            RoundedRectangle(cornerRadius: Radius.medium * u, style: .continuous)
                                .fill(wins.contains(i) ? palette.win : palette.sunk)
                            if mark != "." {
                                PixelMark(mark: mark)
                                    .foregroundStyle(wins.contains(i) ? palette.winFg : palette.mark(mark))
                                    .padding(27 * u)
                            }
                        }
                        .frame(width: 104.6 * u, height: 104.6 * u)
                    }
                }
            }
        }
        .padding(6 * u)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.large * u, style: .continuous))
        .padding(-6 * u)
    }
}
