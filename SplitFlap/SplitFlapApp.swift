import SwiftUI

@main
struct SplitFlapApp: App {
    init() {
        // Warm up the audio engine so the first landing click has no latency.
        SoundController.shared.prepare()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
