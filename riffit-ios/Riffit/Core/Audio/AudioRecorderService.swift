import AVFoundation
import Foundation

/// Records audio to the app's local documents directory.
/// Files are saved as m4a (AAC) with a UUID filename so they can
/// be uploaded to Supabase Storage later without renaming.
@MainActor
class AudioRecorderService: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var currentFileURL: URL?

    /// The directory where voice notes are stored locally.
    /// Creates the directory if it doesn't exist.
    private static var voiceNotesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("voice_notes", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Requests microphone permission. Returns true if granted.
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Starts recording to a new file. Call stopRecording() to finish.
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            return
        }

        // UUID filename for easy Supabase upload later
        let fileName = UUID().uuidString + ".m4a"
        let fileURL = Self.voiceNotesDirectory.appendingPathComponent(fileName)
        currentFileURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder?.record()
            isRecording = true
            recordingDuration = 0

            // Update duration every 0.1s for the UI timer display
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.recordingDuration = self?.recorder?.currentTime ?? 0
                }
            }
        } catch {
            currentFileURL = nil
        }
    }

    /// Stops recording and returns the file URL and duration in seconds.
    /// Returns nil if no recording was in progress.
    func stopRecording() -> (url: URL, durationSeconds: Int)? {
        timer?.invalidate()
        timer = nil

        guard let recorder, recorder.isRecording else {
            isRecording = false
            return nil
        }

        let duration = Int(recorder.currentTime)
        recorder.stop()
        self.recorder = nil
        isRecording = false

        guard let fileURL = currentFileURL else { return nil }
        currentFileURL = nil

        return (url: fileURL, durationSeconds: max(duration, 1))
    }

    /// Deletes a voice note file from local storage.
    static func deleteFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
