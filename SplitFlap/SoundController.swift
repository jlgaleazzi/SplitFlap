import AVFoundation
import Foundation

/// Plays a short mechanical click each time a flap lands.
///
/// Three player nodes are round-robined so overlapping landings (the cascade
/// wave) layer without cancelling each other, and each node runs at a
/// slightly different pitch so the clicks don't sound robotic.
final class SoundController {

    static let shared = SoundController()

    var muted = false

    private var engine: AVAudioEngine?
    private var players: [AVAudioPlayerNode] = []
    private var buffer: AVAudioPCMBuffer?
    private var nextPlayer = 0
    private var prepared = false

    private init() {}

    /// Load the sample and start the engine. Safe to call repeatedly.
    func prepare() {
        guard !prepared else { return }
        prepared = true

        guard
            let url = Bundle.main.url(forResource: "flap_click", withExtension: "wav"),
            let file = try? AVAudioFile(forReading: url)
        else { return }

        let format = file.processingFormat
        guard let buf = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else { return }
        do { try file.read(into: buf) } catch { return }
        buffer = buf

        let engine = AVAudioEngine()
        let pitches: [Float] = [0.93, 1.0, 1.07]
        for pitch in pitches {
            let node = AVAudioPlayerNode()
            node.rate = pitch
            node.volume = 0.6
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            players.append(node)
        }
        engine.mainMixerNode.outputVolume = 0.8

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            try engine.start()
            for node in players where !node.isPlaying {
                node.play()
            }
        } catch {
            self.engine = nil
            players = []
            buffer = nil
            prepared = false
            return
        }
        self.engine = engine
    }

    /// Schedule one click `delay` seconds from now.
    func play(landingIn delay: TimeInterval) {
        guard !muted, let buf = buffer, let engine, engine.isRunning, !players.isEmpty else { return }
        let node = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        let hostTime = mach_absolute_time() + UInt64(max(0, delay) * 1_000_000_000)
            node.scheduleBuffer(buf, at: AVAudioTime(hostTime: hostTime), options: [])
    }
}
