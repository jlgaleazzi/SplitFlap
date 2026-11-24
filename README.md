# SplitFlap

A SwiftUI iPad app that simulates a classic Solari-style **split-flap
display**. Type a message in the text area at the bottom of the screen and
watch the board's flaps flip over to reveal it — letter by letter, with the
characteristic flicker, left-to-right cascade, and *thock* of the real
hardware.

## Features

- **Adjustable board size** — 15–40 columns wide, 3–8 rows high (minimum
  15 × 3); flaps auto-size to fit the screen in either orientation
- **Multi-line messages** — each line of the text area becomes one row of
  the board, left-aligned, with blank flaps filling the rest
- **Authentic flip animation**, computed per frame:
  - each flap rotates 180° around its bottom pivot (the cell's midline),
    foreshortened and shaded as it swings
  - the front face flickers through a few intermediate letters, then the
    back face — printed with the incoming letter — swings into place
  - slow start → fast middle → sharp landing with a small mechanical
    overshoot and settle
  - the wave cascades left-to-right, row by row
- **Live updating** — the board retargets as you type; flaps already in
  flight simply land on the newest letter
- **Two themes** — Classic airport (charcoal flaps, cream letters) and
  Retro cream, switchable in the control deck
- **Speed slider** (0.25× – 3×) to admire the mechanism in slow motion
- **Landing clicks** — a synthesized mechanical thock, scheduled to each
  flap's landing moment and played through three slightly detuned voices so
  the cascade sounds like a real board (mutable)
- **Presets** for instant full-board messages
- All settings (size, speed, theme, sound, message) persist across launches

## Requirements

- macOS with **Xcode 15 or newer**
- The app targets **iPad only**, minimum **iOS 17**
- Any iPad simulator works (e.g. *iPad Pro 11-inch*); no signing needed
  for simulator builds

## Getting started

1. Open `SplitFlap.xcodeproj` in Xcode.
2. Select the **SplitFlap** scheme and an iPad simulator.
3. Press **Run** (⌘R).

To install on a physical iPad, set your signing team under
*SplitFlap → Signing & Capabilities*.

## Controls

| Control       | Range    | What it does                              |
|---------------|----------|-------------------------------------------|
| `W` stepper   | 15 – 40  | Board width in characters                 |
| `H` stepper   | 3 – 8    | Board height in rows                      |
| Theme picker  | 2 options | Flap color palette                       |
| Speaker toggle| on / off | Landing click sound                       |
| Speed slider  | 0.25× – 3× | Flip speed (lower = more dramatic)      |
| Preset chips  | —        | Loads a full-board message                |
| `CLEAR`       | —        | Flips the whole board to blanks           |

Accepted characters: A–Z, 0–9, space, and `.,!?-/:`. Anything else becomes
a blank flap. Input is auto-uppercased, just like the real hardware.

## How the animation works

Each cell stores two characters: `front` (top half) and `target` (bottom
half — the flap behind it, which is why you can glimpse the incoming letter
at rest, exactly like a real Solari board). When a cell's letter changes,
the top flap rotates 0°→180° around its bottom edge:

- the flap's apparent height is `h·|cos θ|`, anchored at the midline pivot
- its surface is shaded with `0.42 + 0.58·|cos θ|` to fake the lighting
- the back face is drawn with the incoming letter so it lands upright
- a deterministic per-cell seed picks the intermediate flicker letters, so
  the animation is stable across redraws

Per-frame state is a pure function of time (`CellState.face(at:)`), and the
`TimelineView` pauses automatically the moment the whole board is at rest —
the app idles quietly until the next keystroke.

## Project layout

```
SplitFlap.xcodeproj            Hand-written, minimal, iPad-only
SplitFlap/
├── SplitFlapApp.swift         @main entry, audio warm-up
├── ContentView.swift          Layout + control deck
├── SplitFlapDisplay.swift     Canvas renderer + board layout math
├── SplitFlapModel.swift       Grid state, animation math, persistence
├── FlapTheme.swift            Classic / Retro palettes
├── SoundController.swift      AVAudioEngine landing clicks
├── Resources/flap_click.wav   Synthesized mechanical thock
└── Assets.xcassets            App icon + accent color
```

## Tuning

The feel lives in `SplitFlapModel.swift`:

- `baseDuration` (0.6 s) — one flip at 1× speed
- `baseOvershoot` (0.14 s) — settle time after landing
- `baseColDelay` / `baseRowDelay` — the cascade wave spacing
- `CellState.progress(_:)` — the acceleration curve
- `CellState.flickCount` — how many letters flash by per flip
- `minColumns…maxRows` — the allowed board sizes
- `FlapTheme.swift` — both palettes
