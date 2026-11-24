import SwiftUI

/// The physical board: a rows × columns grid of flap cells, rendered in a
/// single Canvas driven by TimelineView so every flap animates in sync.
struct SplitFlapDisplay: View {
    var model: SplitFlapModel

    var body: some View {
        let theme = model.theme
        GeometryReader { geo in
            let layout = BoardLayout(canvas: geo.size, rows: model.rows, columns: model.columns)
            // The timeline pauses automatically while the whole board is at rest.
            TimelineView(.animation(minimumInterval: nil, paused: model.isIdle)) { timeline in
                let now = timeline.date
                let grid = model.grid
                let duration = model.duration
                let overshoot = model.overshootSpan
                Canvas { context, _ in
                    renderBoard(
                        context: &context,
                        layout: layout,
                        grid: grid,
                        theme: theme,
                        now: now,
                        duration: duration,
                        overshoot: overshoot
                    )
                }
                .onChange(of: now) { _, newNow in
                    model.tick(now: newNow)
                }
            }
        }
    }

    // MARK: - Rendering

    private func renderBoard(
        context: inout GraphicsContext,
        layout: BoardLayout,
        grid: [[CellState]],
        theme: FlapTheme,
        now: Date,
        duration: Double,
        overshoot: Double
    ) {
        // Device panel behind the grid.
        let frame = layout.boardRect.insetBy(dx: -layout.framePad, dy: -layout.framePad)
        let radius = max(10, frame.width * 0.015)
        var panel = context
        panel.addFilter(.shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10))
        panel.fill(Path(roundedRect: frame, cornerRadius: radius), with: .color(theme.panel.color))
        panel.stroke(
            Path(roundedRect: frame, cornerRadius: radius),
            with: .color(theme.chrome.color(0.14)), lineWidth: 1
        )

        // Flaps.
        let corner = layout.cellW * 0.055
        for (r, row) in grid.enumerated() {
            for (c, cell) in row.enumerated() {
                let rect = layout.cellRect(row: r, col: c)
                drawCell(
                    context: &context, rect: rect, cell: cell, theme: theme,
                    now: now, duration: duration, overshoot: overshoot, corner: corner
                )
            }
        }
    }

    private func drawCell(
        context: inout GraphicsContext,
        rect: CGRect,
        cell: CellState,
        theme: FlapTheme,
        now: Date,
        duration: Double,
        overshoot: Double,
        corner: CGFloat
    ) {
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let midY = rect.minY + h / 2
        let halfH = h / 2
        let inset = max(1, w * 0.012)

        // 1. The well behind everything (the dark gap).
        context.fill(Path(roundedRect: rect, cornerRadius: corner), with: .color(theme.gap.color))

        // 2. The flap behind: always shows the incoming letter in the bottom half.
        let backRect = CGRect(x: x + inset, y: midY + inset * 0.5,
                              width: w - inset * 2, height: halfH - inset * 0.5)
        context.fill(
            Path(roundedRect: backRect, cornerRadius: corner * 0.5),
            with: .color(theme.flapFace.scaled(0.85))
        )
        drawLetter(
            context: &context, ch: cell.target,
            centerX: x + w / 2, centerY: midY + halfH / 2,
            fontSize: h * 0.40, color: theme.letter.scaled(0.92)
        )

        // 3. The moving flap, rotating around the midline pivot.
        let face = cell.face(at: now, duration: duration, overshoot: overshoot)
        let degrees = face.angleDeg
        let c = abs(cos(degrees * .pi / 180))
        let flapH = halfH * c
        let brightness = 0.42 + 0.58 * c
        let frontVisible = degrees < 90

        let flapRect = frontVisible
            ? CGRect(x: x + inset, y: midY - flapH, width: w - inset * 2, height: flapH)
            : CGRect(x: x + inset, y: midY, width: w - inset * 2, height: flapH)
        context.fill(Path(rect: flapRect), with: .color(theme.flapFace.scaled(brightness)))

        if flapH > 2 {
            // Top-edge bevel.
            let bevelH = max(1, h * 0.01)
            let bevel = CGRect(x: flapRect.minX, y: flapRect.minY, width: flapRect.width, height: bevelH)
            context.fill(Path(rect: bevel), with: .white.opacity(0.05 * brightness))

            // The letter, vertically compressed around the pivot as the flap swings.
            var letterCtx = context
            letterCtx.translateBy(x: x + w / 2, y: midY)
            letterCtx.scaleBy(x: 1, y: c)
            let ch = frontVisible ? face.front : face.back
            let localCenter: CGFloat = frontVisible ? -halfH / 2 : halfH / 2
            letterCtx.draw(
                Text(verbatim: String(ch))
                    .font(.system(size: h * 0.40, weight: .bold))
                    .foregroundStyle(theme.letter.scaled(brightness)),
                at: CGPoint(x: 0, y: localCenter), anchor: .center
            )
        }

        // 4. The axle line at the pivot.
        let axleH = max(1.5, h * 0.02)
        let axle = CGRect(x: x + inset * 1.5, y: midY - axleH / 2, width: w - inset * 3, height: axleH)
        context.fill(Path(rect: axle), with: .color(theme.gap.color(0.85)))
    }

    private func drawLetter(
        context: inout GraphicsContext,
        ch: Character,
        centerX: CGFloat,
        centerY: CGFloat,
        fontSize: CGFloat,
        color: Color
    ) {
        context.draw(
            Text(verbatim: String(ch))
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(color),
            at: CGPoint(x: centerX, y: centerY), anchor: .center
        )
    }
}

/// Maps the board into the available canvas: flaps auto-size to fit both
/// width and height, and the grid is centered.
struct BoardLayout {
    let cellW: CGFloat
    let cellH: CGFloat
    let gapX: CGFloat
    let gapY: CGFloat
    let boardRect: CGRect
    let framePad: CGFloat

    init(canvas: CGSize, rows: Int, columns: Int) {
        let aspect: CGFloat = 1.4          // cell height / width
        let gapFactor: CGFloat = 0.05
        let maxCell: CGFloat = 120
        let pad: CGFloat = 26

        let cols = max(1, columns)
        let rws = max(1, rows)

        let wBudget = max(10, canvas.width - pad * 2)
        let colSpan = CGFloat(cols) + gapFactor * CGFloat(cols - 1)
        let hBudget = max(10, canvas.height - pad * 2)
        let rowSpan = aspect * (CGFloat(rws) + gapFactor * CGFloat(rws - 1))

        let cw = min(maxCell, wBudget / colSpan, hBudget / rowSpan)

        let cellW = cw
        let cellH = cw * aspect
        let gapX = cw * gapFactor
        let gapY = cw * aspect * gapFactor
        let boardW = CGFloat(cols) * cw + CGFloat(cols - 1) * gapX
        let boardH = CGFloat(rws) * cellH + CGFloat(rws - 1) * gapY
        let origin = CGPoint(
            x: (canvas.width - boardW) / 2,
            y: (canvas.height - boardH) / 2
        )

        self.cellW = cellW
        self.cellH = cellH
        self.gapX = gapX
        self.gapY = gapY
        self.boardRect = CGRect(origin: origin, size: CGSize(width: boardW, height: boardH))
        self.framePad = pad
    }

    func cellRect(row: Int, col: Int) -> CGRect {
        CGRect(
            x: boardRect.minX + CGFloat(col) * (cellW + gapX),
            y: boardRect.minY + CGFloat(row) * (cellH + gapY),
            width: cellW,
            height: cellH
        )
    }
}
