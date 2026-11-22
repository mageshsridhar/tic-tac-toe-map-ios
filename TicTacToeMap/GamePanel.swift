import SwiftUI

/// The game card (whose turn it is, the board, Undo / New game) and, unless the layout
/// places it elsewhere, the endings card below it.
struct GamePanel: View {
    @Bindable var model: GameModel
    var showsEndings = true
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 20) {
                StatusRow(model: model)
                BoardGrid(model: model)
                    // Rebuilt from scratch on a theme change: a square could otherwise occasionally keep
                    // its old colours (likely a cached pointer-hover highlight surviving the switch).
                    .id(scheme)
                HStack(spacing: 12) {
                    PillButton(title: "Undo", systemImage: "arrow.uturn.backward", style: .plain) { model.undo() }
                        .keyboardShortcut("z", modifiers: .command)
                        .disabled(model.movesPlayed == 0)
                    PillButton(title: "New game", systemImage: "arrow.counterclockwise", style: .primary) { model.restart() }
                        .keyboardShortcut("n", modifiers: .command)
                }
            }
            .card()
            if showsEndings {
                EndingsCard(model: model)
            }
        }
        // The board and meter have a fixed grid, so very large text sizes are capped here.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

/// The endings meter in its own card.
struct EndingsCard: View {
    let model: GameModel
    /// Take the whole space the layout offers: the dots grow to fill the width,
    /// and the rows spread out evenly over the height.
    var fills = false

    var body: some View {
        Group {
            if fills {
                GeometryReader { geo in
                    EndingsMeter(model: model, scale: EndingsMeter.scale(fitting: geo.size), spread: true)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                }
            } else {
                EndingsMeter(model: model)
            }
        }
        .card()
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

/// The rounded, outlined surface every panel on the left sits on.
private struct CardStyle: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.large, style: .continuous).strokeBorder(palette.line, lineWidth: 2))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

private struct StatusRow: View {
    @Environment(\.palette) private var palette
    let model: GameModel

    var body: some View {
        let board = model.current
        let winner = board.winner
        let turn = board.turn
        let badge: Outcome = winner ?? (turn == "X" ? .x : .o)
        HStack(spacing: 14) {
            Text(winner == .draw ? "=" : String(winner == nil ? turn : (winner == .x ? "X" : "O")))
                .font(.ui(22, .heavy))
                .foregroundStyle(palette.ink(badge))
                .frame(width: 40, height: 40)
                .background(palette.soft(badge), in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(winner.map { $0 == .draw ? "It's a draw" : $0.label } ?? "\(turn) to move")
                    .font(.ui(20, .heavy))
                    .foregroundStyle(palette.fg)
                // Always one line, so the panel never changes height between moves.
                HStack(spacing: 6) {
                    if winner != nil {
                        Text("Finished in \(model.movesPlayed) moves")
                    } else {
                        let v = Solver.shared.value(of: board)
                        Text("Best play from here:")
                        Text(v.label)
                            .font(.ui(13, .bold))
                            .foregroundStyle(palette.ink(v))
                            .padding(.horizontal, 10).padding(.vertical, 2)
                            .background(palette.soft(v), in: Capsule())
                    }
                }
                .font(.ui(15))
                .foregroundStyle(palette.muted)
                .lineLimit(1)
            }
        }
    }
}

/// The 3x3 board: rounded tiles with pixel-art marks. Hovering an empty tile previews your mark.
private struct BoardGrid: View {
    @Environment(\.palette) private var palette
    @Bindable var model: GameModel
    @State private var hovered: Int?

    var body: some View {
        let board = model.current
        let over = board.winner != nil
        let wins = board.winningCells
        let turn = board.turn
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { col in
                        let i = row * 3 + col
                        let mark = board.cells[i]
                        let peeked = !over && mark == "." && (hovered == i || peekMatches(i, board))
                        Button { model.play(i) } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                                    .fill(wins.contains(i) ? palette.win : peeked ? palette.line : palette.sunk)
                                if mark != "." {
                                    PixelMark(mark: mark)
                                        .foregroundStyle(wins.contains(i) ? palette.winFg : palette.mark(mark))
                                        .padding(27)
                                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                                } else if peeked {
                                    PixelMark(mark: turn)
                                        .foregroundStyle(palette.mark(turn).opacity(0.3))
                                        .padding(27)
                                }
                            }
                            .frame(width: 104.6, height: 104.6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.highlight)
                        // Not .disabled: that would grey out the marks. play() ignores taps on filled squares.
                        .onHover { inside in
                            hovered = inside ? i : (hovered == i ? nil : hovered)
                            if !over && mark == "." {
                                model.peekKey = inside ? board.placing(i).canonical : nil
                            }
                        }
                        .accessibilityLabel("Row \(row + 1), column \(col + 1)")
                        .accessibilityValue(mark == "." ? "Empty" : String(mark))
                        .accessibilityHint(mark == "." && !over ? "Places \(turn)" : "")
                    }
                }
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("root")) } action: { model.boardFrame = $0 }
        .frame(maxWidth: .infinity)
    }

    private func peekMatches(_ i: Int, _ board: Board) -> Bool {
        guard let key = model.peekKey else { return false }
        return board.placing(i).canonical == key
    }
}

struct PillButton: View {
    enum Style { case plain, primary }
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let systemImage: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.ui(15, .bold))
                .foregroundStyle(style == .primary ? palette.xInk : palette.fg)
                .frame(maxWidth: .infinity, minHeight: 44)   // HIG minimum hit target
                .background(style == .primary ? palette.xSoft : palette.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(style == .primary ? palette.x : palette.line, lineWidth: 2))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

/// One row of dots per result. Lit dots are endings still reachable from the current position.
private struct EndingsMeter: View {
    @Environment(\.palette) private var palette
    let model: GameModel
    /// Dot size relative to the standard 8pt dots.
    var scale: CGFloat = 1
    /// Spread the rows evenly over the height on offer instead of stacking them tightly.
    var spread = false

    private static let labelWidth: CGFloat = 118, labelGap: CGFloat = 12

    /// The largest dot scale that fits `size`: 20 dots across beside the labels, and the
    /// nine rows of dots (5 + 3 + 1) plus the heading and some room between rows down.
    static func scale(fitting size: CGSize) -> CGFloat {
        let byWidth = (size.width - labelWidth - labelGap) / (20 * 8 + 19 * 2)
        let byHeight = (size.height - 20 - 3 * 20) / (9 * 10)
        return max(1, min(byWidth, byHeight, 2.4))
    }

    var body: some View {
        let board = model.current
        let solver = Solver.shared
        let over = board.winner != nil
        let reachable = solver.endings(from: board)
        let finalKey = over ? board.canonical : nil
        VStack(alignment: .leading, spacing: spread ? 0 : 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(over ? "YOUR ENDING AMONG ALL 138" : "ENDINGS STILL POSSIBLE")
                    .font(.ui(12, .heavy)).kerning(0.7)
                    .foregroundStyle(palette.muted)
                Spacer()
                Text(over ? "#\(solver.endingNumber[finalKey!]!)" : "\(reachable.count) / 138")
                    .font(.ui(14, .bold)).monospacedDigit()
                    .foregroundStyle(palette.fg)
            }
            ForEach(Outcome.allCases, id: \.self) { result in
                let keys = solver.allEndings.filter { Board($0).winner == result }
                let lit = keys.filter { reachable.contains($0) }.count
                if spread { Spacer(minLength: 12) }
                // Each label lines up with the middle of its first row of dots.
                HStack(alignment: .firstDotRow, spacing: Self.labelGap) {
                    HStack(spacing: 7) {
                        Circle().fill(palette.color(result)).frame(width: 10, height: 10)
                        Text(result.label).font(.ui(15)).foregroundStyle(palette.muted)
                        Spacer(minLength: 0)
                        if !over {
                            Text(lit == result.total ? "\(result.total)" : "\(lit)/\(result.total)")
                                .font(.ui(13, .bold)).monospacedDigit()
                                .foregroundStyle(palette.fg)
                        }
                    }
                    .frame(width: Self.labelWidth, alignment: .leading)
                    let dot = 8 * scale, gap = 2 * scale
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(dot), spacing: gap), count: 20), alignment: .leading, spacing: gap) {
                        ForEach(keys, id: \.self) { key in
                            let on = reachable.contains(key)
                            let isFinal = key == finalKey
                            // The ending you reached: a smaller dot inside a ring that stays within
                            // its own cell (dot plus gap), so it never covers the dots beside it.
                            Circle()
                                .fill(on ? palette.color(result) : palette.line)
                                .opacity(on ? 1 : 0.6)
                                .frame(width: isFinal ? dot * 0.62 : dot, height: isFinal ? dot * 0.62 : dot)
                                .frame(width: dot, height: dot)
                                .overlay {
                                    if isFinal {
                                        Circle().strokeBorder(palette.fg, lineWidth: 1.5 * scale)
                                            .frame(width: dot + gap, height: dot + gap)
                                    }
                                }
                        }
                    }
                    .frame(width: 20 * dot + 19 * gap, alignment: .leading)
                    .alignmentGuide(.firstDotRow) { _ in dot / 2 }
                }
            }
        }
    }
}

private extension VerticalAlignment {
    /// The middle of a legend row's label, matched to the middle of its first row of dots.
    enum FirstDotRow: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d[VerticalAlignment.center] }
    }
    static let firstDotRow = VerticalAlignment(FirstDotRow.self)
}
