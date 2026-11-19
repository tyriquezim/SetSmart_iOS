import AVFoundation

/// Plays a 3-beep alarm in-app.
/// `scheduleLooping(at:)` pre-schedules the alarm so it fires even when the app is backgrounded
/// (requires the Audio background mode capability). `stop()` cancels everything.
final class AlarmService {
    static let shared = AlarmService()

    private var engine      = AVAudioEngine()
    private var playerNode  = AVAudioPlayerNode()
    private lazy var buffer        = generateBuffer()
    private lazy var silenceBuffer = makeSilenceBuffer()

    // Pre-scheduling state — only mutated on main thread
    private var alarmScheduledAt: Date = .distantFuture
    private var isPreScheduling = false

    private init() {
        engine.attach(playerNode)
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(playerNode, to: engine.mainMixerNode, format: fmt)
    }

    // MARK: - Public API

    // One-shot play (settings test, etc.)
    func play() {
        guard WorkoutSettings.shared.alarmSoundEnabled, let buffer else { return }
        start(buffer: buffer, options: [])
        HapticsService.restOver()
    }

    // Immediate looping alarm — used when app is in the foreground.
    func playLooping() {
        guard WorkoutSettings.shared.alarmSoundEnabled, let buffer else { return }
        isPreScheduling = false
        alarmScheduledAt = .distantFuture
        start(buffer: buffer, options: .loops)
        HapticsService.restOver()
    }

    // Pre-schedules the looping alarm to fire at `date`.
    // Outputs silence until then so the audio session stays alive in the background.
    // With the Audio background mode, this fires even when the user is in another app.
    func scheduleLooping(at date: Date) {
        guard WorkoutSettings.shared.alarmSoundEnabled, let buffer else { return }
        alarmScheduledAt = date
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            if !engine.isRunning { try engine.start() }
            playerNode.stop()
        } catch { return }

        if date.timeIntervalSinceNow > 0.05 {
            isPreScheduling = true
            scheduleSilenceChunk()
        } else {
            isPreScheduling = false
            playerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        }
        playerNode.play()
    }

    func stop() {
        isPreScheduling = false
        alarmScheduledAt = .distantFuture
        playerNode.stop()
    }

    // MARK: - Private

    // Chains 0.1-second silence buffers until alarmScheduledAt, then switches to looping alarm.
    // This keeps the audio session alive in the background between scheduling and alarm fire time.
    private func scheduleSilenceChunk() {
        guard let silence = silenceBuffer else { return }
        playerNode.scheduleBuffer(silence, at: nil, options: []) { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.isPreScheduling else { return }
                if Date() >= self.alarmScheduledAt {
                    self.isPreScheduling = false
                    guard let buf = self.buffer else { return }
                    self.playerNode.scheduleBuffer(buf, at: nil, options: .loops, completionHandler: nil)
                } else {
                    self.scheduleSilenceChunk()
                }
            }
        }
    }

    private func start(buffer: AVAudioPCMBuffer, options: AVAudioPlayerNodeBufferOptions) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            if !engine.isRunning { try engine.start() }
            playerNode.stop()
            playerNode.scheduleBuffer(buffer, at: nil, options: options, completionHandler: nil)
            if !playerNode.isPlaying { playerNode.play() }
        } catch {}
    }

    // 0.1-second silence buffer — tiny (< 20 KB), reused for every chunk.
    private func makeSilenceBuffer() -> AVAudioPCMBuffer? {
        let sr: Double = 44100
        let frames = AVAudioFrameCount(sr * 0.1)
        let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames) else { return nil }
        buf.frameLength = frames
        return buf // floatChannelData is zeroed by default
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
