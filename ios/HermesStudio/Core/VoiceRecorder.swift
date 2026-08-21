import AVFoundation
import Foundation

@MainActor
final class VoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var elapsed: TimeInterval = 0
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var outputURL: URL?

    func toggle() async -> URL? {
        if isRecording { return stop() }
        let granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard granted else { return nil }
        do {
            let session = AVAudioSession.sharedInstance(); try session.setCategory(.record, mode: .spokenAudio); try session.setActive(true)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("hermes-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
            let recorder = try AVAudioRecorder(url: url, settings: settings); recorder.delegate = self; recorder.record()
            self.recorder = recorder; outputURL = url; elapsed = 0; isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in Task { @MainActor in self?.elapsed = self?.recorder?.currentTime ?? 0 } }
        } catch { return nil }
        return nil
    }

    func stop() -> URL? {
        recorder?.stop(); recorder = nil; timer?.invalidate(); timer = nil; isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        return outputURL
    }
}

@MainActor
final class SpeechPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    private var player: AVAudioPlayer?

    func play(_ data: Data) throws {
        stop()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio)
        try session.setActive(true)
        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        player.prepareToPlay()
        player.play()
        self.player = player
        isPlaying = true
    }

    func stop() {
        player?.stop(); player = nil; isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in stop() }
    }
}
