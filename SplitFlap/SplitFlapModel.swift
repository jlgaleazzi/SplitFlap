import Foundation
import Observation

/// One flap position on the board.
///
/// `front` is the character currently shown in the top half of the cell;
/// `target` is the character the flap is going to land on — it is already
/// peeking through the bottom half from the flap behind, exactly like a real
/// Solari display. While a flip is in flight `flipStart` marks when it began;
/// otherwise the cell is at rest.
struct CellState: Equatable {
    var front: Character
    var target: Character
    var flipStart: Date?
    var seed: UInt64
}

/// The pure per-frame rendering state of a cell.
struct CellFace: Equatable {
    var angleDeg: Double
    var front: Character
    var back: Character
}

extension CellState {

    /// Characters a flap can flick through while turning.
    static let pool: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

    /// How many intermediate characters flash by during the first half of a flip.
    static let flickCount = 6

    /// The visual state of this cell at an instant of time.
    /// Pure — no mutation — so it can be evaluated every frame in the Canvas renderer.
    func face(at now: Date, duration: Double, overshootSpan: Double) -> CellFace {
        guard let start = flipStart else {
            return CellFace(angleDeg: 0, front: front, back: target)
        }
        let d = max(duration, 0.001)
        let t = now.timeIntervalSince(start) / d
        let overshootT = max(0.05, overshootSpan / d)
        if t >= 1 + overshootT {
            // Long past landing: report the settled state.
            return CellFace(angleDeg: 180, front: target, back: target)
        }
        let tc = min(max(t, 0), 1)
        var degrees = 180 * Self.progress(tc)
        // Small mechanical overshoot past 180°, then settle back.
        if t > 1 {
            degrees += 7 * sin(.pi * (t - 1) / overshootT)
        }
        let frontChar: Character
        if t < 0.5 {
            // First half: front face visible, flicking through intermediate letters.
            let idx = min(Self.flickCount, Int((t / 0.5) * Double(Self.flickCount)))
            frontChar = Self.flickChar(seed: seed, idx: idx, from: front, to: target)
        } else {
            frontChar = target
        }
        return CellFace(angleDeg: degrees, front: frontChar, back: target)
    }

    /// Slow start, fast middle, sharp landing.
    static func progress(_ t: Double) -> Double {
        if t < 0.6 {
            let u = t / 0.6
            return 0.72 * u * u
        }
        let u = (t - 0.6) / 0.4
        return 0.72 + 0.28 * (1 - pow(1 - u, 3))
    }

    /// Deterministic pseudo-random intermediate letter for a given flip step,
    /// so the animation is stable across frame redraws.
    static func flickChar(seed: UInt64, idx: Int, from: Character, to: Character) -> Character {
        if idx <= 0 { return from }
        if idx >= flickCount { return to }
        var h = seed &+ (UInt64(idx) &* 0x9E3779B97F4A7C15)
        h ^= h >> 33
        h = h &* 0xFF51AFD7ED558CCD
        h ^= h >> 33
        h = h &* 0xC2B2AE3D27D4EB4F
        h ^= h >> 31
        return pool[Int(h % UInt64(pool.count))]
    }
}

@Observable
final class SplitFlapModel {

    // MARK: - Grid limits

    static let minColumns = 15
    static let maxColumns = 40
    static let minRows = 3
    static let maxRows = 8

    // MARK: - User controls (all persisted)

    var columns: Int {
        didSet {
            guard oldValue != columns else { return }
            syncGrid()
            persist()
        }
    }
    var rows: Int {
        didSet {
            guard oldValue != rows else { return }
            syncGrid()
            persist()
        }
    }
    var speed: Double {
        didSet {
            guard oldValue != speed else { return }
            persist()
        }
    }
    var soundOn: Bool {
        didSet {
            guard oldValue != soundOn else { return }
            SoundController.shared.muted = !soundOn
            persist()
        }
    }
    var themeName: String {
        didSet {
            guard oldValue != themeName else { return }
            persist()
        }
    }
    var message: String {
        didSet {
            guard oldValue != message else { return }
            retarget(at: Date())
            persist()
        }
    }

    // MARK: - Board state

    private(set) var grid: [[CellState]] = []

    static let classicThemeID = "classic"
    static let retroThemeID = "retro"

    var theme: FlapTheme {
        themeName == Self.retroThemeID ? .retro : .classic
    }

    var presets: [String] {
        [
            "DEPARTURES\nGATE 12\nBOARDING",
            "GOOD MORNING\nWELCOME ABOARD\nHAVE A NICE DAY",
            "SPLIT FLAP\nSWIFTUI CANVAS\nFLYING HIGH",
            "HELLO WORLD\nTHIS IS A\nSPLIT FLAP",
        ]
    }

    /// True when no cell is mid-flip — the animation timeline pauses then.
    var isIdle: Bool {
        grid.allSatisfy { row in row.allSatisfy { $0.flipStart == nil } }
    }

    // MARK: - Timing

    private static let baseDuration: Double = 0.6      // one flip at 1× speed
    private static let baseOvershoot: Double = 0.14    // settle time after landing
    private static let baseColDelay: Double = 0.022    // cascade wave, per column
    private static let baseRowDelay: Double = 0.045    // cascade wave, per row

    var duration: Double { Self.baseDuration / max(speed, 0.05) }
    var overshootSpan: Double { Self.baseOvershoot / max(speed, 0.05) }

    @ObservationIgnored private var lastTick: Date = .distantPast

    // MARK: - Init

    init() {
        let d = UserDefaults.standard
        let cols = (d.object(forKey: Keys.columns) as? Int) ?? 15
        let rws = (d.object(forKey: Keys.rows) as? Int) ?? 3
        let spd = (d.object(forKey: Keys.speed) as? Double) ?? 1.0
        let snd = (d.object(forKey: Keys.sound) as? Bool) ?? true
        let thm = (d.object(forKey: Keys.theme) as? String) ?? Self.classicThemeID
        let msg = d.string(forKey: Keys.message) ?? "DEPARTURES\nGATE 12\nBOARDING"

        columns = min(Self.maxColumns, max(Self.minColumns, cols))
        rows = min(Self.maxRows, max(Self.minRows, rws))
        speed = min(3, max(0.25, spd))
        soundOn = snd
        themeName = thm
        message = msg

        grid = makeGrid(at: Date())
        SoundController.shared.muted = !soundOn
    }

    // MARK: - Grid management

    private func makeGrid(at now: Date) -> [[CellState]] {
        (0..<rows).map { r in
            (0..<columns).map { c in
                CellState(
                    front: " ",
                    target: targetChar(row: r, col: c),
                    flipStart: now.addingTimeInterval(delay(row: r, col: c)),
                    seed: Self.seed(row: r, col: c)
                )
            }
        }
    }

    /// Grow or shrink the grid, keeping the existing cells in place.
    private func syncGrid() {
        let now = Date()
        var next: [[CellState]] = []
        for r in 0..<rows {
            var row: [CellState] = []
            for c in 0..<columns {
                if r < grid.count, c < grid[r].count {
                    row.append(grid[r][c])
                } else {
                    row.append(CellState(
                        front: " ",
                        target: targetChar(row: r, col: c),
                        flipStart: now.addingTimeInterval(delay(row: r, col: c)),
                        seed: Self.seed(row: r, col: c)
                    ))
                }
            }
            next.append(row)
        }
        grid = next
        retarget(at: now)
    }

    /// Point every cell at its new target character, starting flips where
    /// needed. Cells already mid-flip simply retarget their landing, so
    /// typing while the board is animating stays smooth.
    private func retarget(at now: Date) {
        for r in 0..<grid.count {
            for c in 0..<grid[r].count {
                let target = targetChar(row: r, col: c)
                var cell = grid[r][c]
                if target != cell.front {
                    cell.target = target
                    if cell.flipStart == nil {
                        cell.flipStart = now.addingTimeInterval(delay(row: r, col: c))
                    }
                }
                if cell != grid[r][c] {
                    grid[r][c] = cell
                }
            }
        }
    }

    private static let allowedPunctuation: Set<Character> = [".", ",", "!", "?", "-", "/", ":"]

    private func targetChar(row: Int, col: Int) -> Character {
        let lines = message
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).uppercased() }
        guard row < lines.count else { return " " }
        let chars = Array(lines[row])
        guard col < chars.count else { return " " }
        let ch = chars[col]
        if ch == " " { return " " }
        if ch.isLetter || ch.isNumber { return ch }
        if Self.allowedPunctuation.contains(ch) { return ch }
        return " "
    }

    /// Cascade delay: the wave travels left-to-right, then down the board.
    private func delay(row: Int, col: Int) -> TimeInterval {
        let base = Self.baseColDelay * Double(col) + Self.baseRowDelay * Double(row)
        return base / max(speed, 0.05)
    }

    private static func seed(row: Int, col: Int) -> UInt64 {
        var h: UInt64 = 0x9E3779B97F4A7C15
        h &+= UInt64(row) &* 0x1F123BB5483707A3
        h &+= UInt64(col) &* 0xCD9E8D57CB42C4E1
        h ^= h >> 33
        h = h &* 0xFF51AFD7ED558CCD
        h ^= h >> 33
        h = h &* 0xC2B2AE3D27D4EB4F
        h ^= h >> 31
        return h
    }

    // MARK: - Frame tick (landings + sound)

    /// Called once per displayed frame. Advances cells whose flip has settled
    /// and schedules the landing click at the right moment.
    func tick(now: Date) {
        defer { lastTick = now }
        let settleSpan = overshootSpan
        for r in 0..<grid.count {
            for c in 0..<grid[r].count {
                guard let start = grid[r][c].flipStart else { continue }
                let landTime = start.addingTimeInterval(duration)
                if now >= landTime + settleSpan {
                    // Flip complete: fold the target into the front and rest.
                    var cell = grid[r][c]
                    cell.front = cell.target
                    cell.flipStart = nil
                    grid[r][c] = cell
                } else if landTime > lastTick && landTime <= now {
                    let late = max(0, now.timeIntervalSince(landTime))
                    SoundController.shared.play(landingIn: min(late, 0.05))
                }
            }
        }
    }

    // MARK: - Persistence

    private func persist() {
        let d = UserDefaults.standard
        d.set(columns, forKey: Keys.columns)
        d.set(rows, forKey: Keys.rows)
        d.set(speed, forKey: Keys.speed)
        d.set(soundOn, forKey: Keys.sound)
        d.set(themeName, forKey: Keys.theme)
        d.set(message, forKey: Keys.message)
    }

    private enum Keys {
        static let columns = "splitflap.columns"
        static let rows = "splitflap.rows"
        static let speed = "splitflap.speed"
        static let sound = "splitflap.sound"
        static let theme = "splitflap.theme"
        static let message = "splitflap.message"
    }
}
