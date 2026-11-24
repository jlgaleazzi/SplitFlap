import SwiftUI

struct ContentView: View {
    @State private var model = SplitFlapModel()

    var body: some View {
        let theme = model.theme
        ZStack {
            theme.screen.color.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                SplitFlapDisplay(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 6)
                controlDeck
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("SPLIT FLAP")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .tracking(8)
                .foregroundStyle(model.theme.chrome.color)
            Text("MECHANICAL DISPLAY SIMULATOR")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(model.theme.chrome.color(0.45))
        }
    }

    // MARK: - Control deck

    private var controlDeck: some View {
        let theme = model.theme
        return VStack(alignment: .leading, spacing: 12) {
            presetRow
            settingsRow
            messageRow
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.panel.color)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(theme.chrome.color(0.18), lineWidth: 1)
                )
        )
    }

    private var presetRow: some View {
        let theme = model.theme
        return HStack(spacing: 8) {
            Text("PRESETS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(theme.chrome.color(0.5))
            ForEach(model.presets, id: \.self) { preset in
                Button {
                    model.message = preset
                } label: {
                    Text(preset.firstLine)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .buttonStyle(ChipStyle(theme: theme))
            }
            Spacer(minLength: 0)
        }
    }

    private var settingsRow: some View {
        let theme = model.theme
        return HStack(spacing: 14) {
            Picker("THEME", selection: $model.themeName) {
                Text("Classic").tag(SplitFlapModel.classicThemeID)
                Text("Retro").tag(SplitFlapModel.retroThemeID)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)

            Toggle(isOn: $model.soundOn) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 13, weight: .semibold))
            }
            .toggleStyle(.button)

            HStack(spacing: 6) {
                Image(systemName: "speedometer")
                    .font(.system(size: 12))
                Slider(value: $model.speed, in: 0.25...3)
                    .frame(minWidth: 110, maxWidth: 240)
                Text(String(format: "%.1f×", model.speed))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .frame(width: 36, alignment: .trailing)
            }

            Stepper(value: $model.columns, in: SplitFlapModel.minColumns...SplitFlapModel.maxColumns) {
                Text("W\(model.columns)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }

            Stepper(value: $model.rows, in: SplitFlapModel.minRows...SplitFlapModel.maxRows) {
                Text("H\(model.rows)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
        }
        .tint(theme.chrome.color)
        .foregroundStyle(theme.chrome.color)
    }

    private var messageRow: some View {
        let theme = model.theme
        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("MESSAGE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(theme.chrome.color(0.5))
                TextEditor(text: $model.message)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.uiText.color)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(height: 72)
                    .background(RoundedRectangle(cornerRadius: 8).fill(theme.gap.color(0.55)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(theme.chrome.color(0.25), lineWidth: 1)
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
            }
            Button("CLEAR") {
                model.message = ""
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .buttonStyle(ChipStyle(theme: theme))
            .padding(.top, 14)
        }
    }
}

// MARK: - Support

struct ChipStyle: ButtonStyle {
    var theme: FlapTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 7).fill(theme.flapFace.color(0.14)))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(theme.chrome.color(0.35), lineWidth: 1)
            )
            .foregroundStyle(theme.uiText.color)
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

private extension String {
    var firstLine: String {
        if let i = range(of: "\n") {
            return String(prefix(upTo: i.lowerBound))
        }
        return self
    }
}
