import AVFoundation

/// Plays a 3-beep alarm in-app (over the user's music).
final class AlarmService {
    static let shared = AlarmService()

    private var engine      = AVAudioEngine()
    private var playerNode  = AVAudioPlayerNode()
    private lazy var buffer = generateBuffer()

    private init() {
        engine.attach(playerNode)
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(playerNode, to: engine.mainMixerNode, format: fmt)
    }

    func play() {
        guard WorkoutSettings.shared.alarmSoundEnabled, let buffer else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            if !engine.isRunning { try engine.start() }
            playerNode.stop()
            playerNode.scheduleBuffer(buffer, at: nil, completionHandler: nil)
            if !playerNode.isPlaying { playerNode.play() }
        } catch { /* non-fatal */ }
        HapticsService.restOver()
    }

    // Three rising beeps: 880, 990, 1100 Hz — square wave, 0.14 s each with 0.14 s gap
    private func generateBuffer() -> AVAudioPCMBuffer? {
        let sr: Double = 44100
        let beep: Double = 0.14, gap: Double = 0.14
        let freqs: [Double] = [880, 990, 1100]
        let total = Double(freqs.count) * (beep + gap)
        let frames = AVAudioFrameCount(sr * total)
        let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames) else { return nil }
        buf.frameLength = frames
        let data = buf.floatChannelData![0]
        var i = 0
        for freq in freqs {
            let beepN = Int(sr * beep)
            let period = sr / freq
            for j in 0..<beepN {
                data[i] = Float(Double(j).truncatingRemainder(dividingBy: period) < period / 2 ? 0.4 : -0.4)
                i += 1
            }
            let gapN = Int(sr * gap)
            for _ in 0..<gapN { data[i] = 0; i += 1 }
        }
        return buf
    }
}
