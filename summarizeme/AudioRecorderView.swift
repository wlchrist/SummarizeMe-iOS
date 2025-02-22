import SwiftUI
import AVFoundation

struct AudioRecorderView: View {
    @StateObject private var recorder = AudioRecorder()
    @State private var audioPlayer: AVAudioPlayer?
    @State private var transcription: String = "No transcription yet"

    var body: some View {
        VStack(spacing: 16) {
            // Recording Status
            Text(recorder.isRecording ? "Recording..." : "Tap to Record")
                .foregroundColor(recorder.isRecording ? .red : .primary)
                .font(.headline)
                .padding()

            // Record Button
            Button(action: {
                recorder.isRecording ? recorder.stopRecording() : recorder.startRecording()
            }) {
                Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
            }
            .padding()

            // Upload Button
            Button(action: {
                recorder.uploadLatestRecording()
            }) {
                Text("Upload & Transcribe")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }

            // Fetch Transcription Button
            Button(action: fetchTranscription) {
                Text("Fetch Transcription")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }

            // Display Transcription Result
            if !transcription.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcription:")
                        .font(.headline)
                    Text(transcription)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .transition(.opacity)
                        .animation(.easeInOut, value: transcription)
                }
                .padding()
            }

            // List of Recordings
            List {
                ForEach(recorder.recordings, id: \.self) { recording in
                    HStack {
                        Text(recording.lastPathComponent)
                        Spacer()
                        Button(action: { playRecording(url: recording) }) {
                            Image(systemName: "play.circle.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                        }
                    }
                }
            }
        }
    }

    private func playRecording(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Playback failed: \(error)")
        }
    }

    private func fetchTranscription() {
        guard let url = URL(string: "http://127.0.0.1:8000/get-transcription/memo_1739696490.565741_summary.txt") else {
            print("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let result = try? JSONDecoder().decode([String: String].self, from: data),
                   let text = result["transcription"] {
                    DispatchQueue.main.async {
                        transcription = text
                    }
                }
            }
        }.resume()
    }
}

