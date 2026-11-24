import SwiftUI

/// A plain RGB triple so colors can be shaded (darkened) at render time.
struct RGB {
    var r: Double
    var g: Double
    var b: Double

    var color: Color { Color(red: r, green: g, blue: b) }

    /// Scales the color toward black — used to fake lighting on the flaps.
    func scaled(_ s: Double) -> Color {
        Color(red: r * s, green: g * s, blue: b * s)
    }

    func color(_ opacity: Double) -> Color {
        Color(red: r, green: g, blue: b).opacity(opacity)
    }
}

/// A complete palette for the board and the controls.
struct FlapTheme {
    let name: String
    let screen: RGB     // app background
    let panel: RGB      // device body behind the flaps
    let gap: RGB        // dark well between flaps
    let flapFace: RGB   // flap surface (at full brightness)
    let letter: RGB     // printed letter color
    let chrome: RGB     // UI accents / control chrome
    let uiText: RGB     // user-facing text (always readable on dark surfaces)

    /// Charcoal flaps, cream letters — the Solari airport look.
    static let classic = FlapTheme(
        name: "Classic airport",
        screen: RGB(r: 0.045, g: 0.045, b: 0.055),
        panel: RGB(r: 0.10, g: 0.10, b: 0.12),
        gap: RGB(r: 0.015, g: 0.015, b: 0.018),
        flapFace: RGB(r: 0.155, g: 0.150, b: 0.145),
        letter: RGB(r: 0.955, g: 0.915, b: 0.80),
        chrome: RGB(r: 0.955, g: 0.915, b: 0.80),
        uiText: RGB(r: 0.955, g: 0.915, b: 0.80)
    )

    /// Cream flaps, black letters — the old office split-flap look.
    static let retro = FlapTheme(
        name: "Retro cream",
        screen: RGB(r: 0.09, g: 0.075, b: 0.06),
        panel: RGB(r: 0.14, g: 0.115, b: 0.09),
        gap: RGB(r: 0.05, g: 0.042, b: 0.035),
        flapFace: RGB(r: 0.90, g: 0.855, b: 0.75),
        letter: RGB(r: 0.09, g: 0.08, b: 0.07),
        chrome: RGB(r: 0.90, g: 0.855, b: 0.75),
        uiText: RGB(r: 0.93, g: 0.89, b: 0.80)
    )
}
