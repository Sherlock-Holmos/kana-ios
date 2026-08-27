import SwiftUI
import AVFoundation

struct SpeakingView: View {
    @ObservedObject private var speaker = SpeakingService.shared
    @ObservedObject private var audio = AudioService.shared

    @State private var sentences: [SentenceItem] = []
    @State private var index: Int = 0
    @State private var selfRating: SpeakingRating?
    @State private var permissionDenied = false
    @State private var error: String?

    private var current: SentenceItem? {
        guard sentences.indices.contains(index) else { return nil }
        return sentences[index]
    }

    var body: some View {
        VStack(spacing: 16) {
            if let error {
                Text(error).foregroundStyle(.red)
            }
            if permissionDenied {
                Text("麦克风权限被拒绝。请到 设置 → 日语学习 → 麦克风 开启。")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding()
            }

            if let s = current {
                promptCard(s)
                playbackControls(s)
                recordingControls
                if let rating = selfRating {
                    ratingRow(rating)
                }
                ratingButtons
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            navRow
            Spacer()
        }
        .padding()
        .navigationTitle("跟读")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func promptCard(_ s: SentenceItem) -> some View {
        VStack(spacing: 8) {
            Text(s.jp)
                .font(.system(size: 28, weight: .medium, design: .serif))
            if let reading = s.reading {
                Text(reading)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            if let zh = s.zh {
                Text(zh)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func playbackControls(_ s: SentenceItem) -> some View {
        HStack(spacing: 10) {
            Button {
                audio.speak(text: s.jp, language: "ja-JP", rate: AVSpeechUtteranceDefaultSpeechRate)
            } label: {
                Label("原速", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                audio.speak(text: s.jp, language: "ja-JP", rate: 0.4)
            } label: {
                Label("慢速", systemImage: "tortoise.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var recordingControls: some View {
        HStack(spacing: 12) {
            if speaker.isRecording {
                Button(role: .destructive) {
                    speaker.stopRecording()
                } label: {
                    Label("停止", systemImage: "stop.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button {
                    Task { await startRecording() }
                } label: {
                    Label("开始录音", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

            Button {
                try? speaker.playLastRecording()
            } label: {
                Label("回听", systemImage: "play.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(speaker.lastRecordingURL == nil)
        }
    }

    private func ratingRow(_ rating: SpeakingRating) -> some View {
        Text("本次自评：\(rating.label)")
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(rating.tint.opacity(0.15), in: Capsule())
            .foregroundStyle(rating.tint)
    }

    private var ratingButtons: some View {
        HStack(spacing: 10) {
            ForEach(SpeakingRating.allCases) { rating in
                Button {
                    selfRating = rating
                } label: {
                    Text(rating.label)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(selfRating == rating ? rating.tint : .gray)
            }
        }
    }

    private var navRow: some View {
        HStack {
            Button {
                prev()
            } label: {
                Label("上一句", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            .disabled(index <= 0)

            Spacer()

            Text("\(index + 1) / \(sentences.count)")
                .font(.caption.monospacedDigit())

            Spacer()

            Button {
                next()
            } label: {
                Label("下一句", systemImage: "chevron.right")
            }
            .buttonStyle(.borderedProminent)
            .disabled(index >= sentences.count - 1)
        }
    }

    private func startRecording() async {
        let granted = await speaker.requestPermission()
        if !granted {
            permissionDenied = true
            return
        }
        permissionDenied = false
        do {
            try speaker.startRecording()
        } catch {
            self.error = "录音启动失败：\(error)"
        }
    }

    private func next() {
        speaker.clearRecording()
        selfRating = nil
        guard index < sentences.count - 1 else { return }
        index += 1
    }

    private func prev() {
        speaker.clearRecording()
        selfRating = nil
        guard index > 0 else { return }
        index -= 1
    }

    private func load() async {
        do {
            let all = try ContentService.shared.loadSentences()
            // Prefer short sentences for shadowing
            sentences = all.filter { $0.jp.count <= 30 }
            error = nil
        } catch {
            self.error = "加载失败：\(error)"
        }
    }
}

enum SpeakingRating: String, CaseIterable, Identifiable {
    case pass = "完成"
    case retry = "再练"

    var id: String { rawValue }

    var label: String { rawValue }

    var tint: Color {
        switch self {
        case .pass: return .green
        case .retry: return .orange
        }
    }
}