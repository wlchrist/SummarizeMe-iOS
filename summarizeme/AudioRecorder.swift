import SwiftUI
import AVFoundation

class AudioRecorder: ObservableObject {
    var audioRecorder: AVAudioRecorder?
    
    @Published var isRecording = false
    @Published var recordings: [URL] = []

    let serverURL = URL(string: "http://127.0.0.1:8000/upload-audio/")!  // Change to your actual API URL

    init() {
        fetchRecordings()
    }

    func startRecording() { 
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try audioSession.setActive(true)

            let fileURL = getNewRecordingURL()
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        fetchRecordings()
    }

    @Published var latestTranscription: String = ""

    func uploadLatestRecording() {
        guard let latestFile = recordings.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).first else {
            print("No recording found to upload")
            return
        }

        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let filename = latestFile.lastPathComponent
        let mimetype = "audio/mp4"

        if let fileData = try? Data(contentsOf: latestFile) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimetype)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        } else {
            print("Failed to read audio file data")
            return
        }

        request.httpBody = body

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Upload error: \(error)")
                return
            }
            if let data = data, let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let transcription = jsonResponse["transcription"] as? String {
                    DispatchQueue.main.async {
                        self.latestTranscription = transcription
                    }
                    print("Transcription: \(transcription)")
                }
            }
        }
        task.resume()
    }

    private func getNewRecordingURL() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let filename = "memo_\(Date().timeIntervalSince1970).m4a"
        return paths[0].appendingPathComponent(filename)
    }

    private func fetchRecordings() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileManager = FileManager.default

        do {
            let files = try fileManager.contentsOfDirectory(at: paths[0], includingPropertiesForKeys: nil)
            self.recordings = files.filter { $0.pathExtension == "m4a" }
        } catch {
            print("Failed to fetch recordings: \(error)")
        }
    }
    
    func fetchTranscription(for filename: String) {
        let transcriptionURL = URL(string: "http://127.0.0.1:8000/get-transcription/\(filename)")!
        
        URLSession.shared.dataTask(with: transcriptionURL) { data, response, error in
            if let error = error {
                print("Error fetching transcription: \(error)")
                return
            }
            if let data = data, let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let transcription = jsonResponse["transcription"] as? String {
                    DispatchQueue.main.async {
                        self.latestTranscription = transcription
                    }
                    print("Transcription received: \(transcription)")
                }
            }
        }.resume()
    }
}

