import SwiftUI
import PencilKit

// MARK: - Drawing canvas wrapper

/// Thin SwiftUI wrapper around PKCanvasView so the challenge screen can embed
/// a finger-friendly drawing surface. PencilKit is the only Apple-blessed way
/// to get pressure + tilt + smooth strokes without writing a custom renderer.
struct DrawingCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput            // finger OR Apple Pencil
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 14)
        canvasView.backgroundColor = .secondarySystemBackground
        canvasView.isOpaque = true
        canvasView.alwaysBounceVertical = false
        canvasView.alwaysBounceHorizontal = false
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

// MARK: - Challenge view

/// KanaWritingChallenge — 5-minute mini-loop embedded at the top of the Learn tab.
/// 10 randomly chosen hiragana, 30 seconds each. User draws with finger in a
/// PKCanvasView. "Done" submits (counts toward today's learn target); "Skip"
/// moves on without counting. Stroke-order templates + accuracy scoring land
/// in v2; the MVP just confirms "did the user draw something at all".
struct KanaWritingChallenge: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var goal: DailyGoalStore

    @State private var pool: [String] = []
    @State private var currentIndex: Int = 0
    @State private var timeRemaining: Int = 30
    @State private var completedCount: Int = 0
    @State private var isFinished: Bool = false
    @State private var canvasView = PKCanvasView()
    @State private var timerTask: Task<Void, Never>?
    @State private var sessionStartedAt: Date = Date()

    private let totalCharacters = 10
    private let secondsPerCharacter = 30

    /// All 46 basic hiragana. Drawn as a flat array so the picker can shuffle freely.
    private let hiraganaBank: [String] = [
        "あ","い","う","え","お",
        "か","き","く","け","こ",
        "さ","し","す","せ","そ",
        "た","ち","つ","て","と",
        "な","に","ぬ","ね","の",
        "は","ひ","ふ","へ","ほ",
        "ま","み","む","め","も",
        "や","ゆ","よ",
        "ら","り","る","れ","ろ",
        "わ","を","ん"
    ]

    var body: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal)
                .padding(.top, 8)

            if isFinished {
                summary
            } else {
                challengeBody
            }
        }
        .navigationTitle("5 分钟手写挑战")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("退出") { finish(commit: false) }
            }
        }
        .onAppear { startSession() }
        .onDisappear { timerTask?.cancel() }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalCharacters, id: \.self) { i in
                Capsule()
                    .fill(colorForSlot(i))
                    .frame(height: 6)
                    .animation(.easeInOut(duration: 0.3), value: currentIndex)
            }
        }
    }

    private func colorForSlot(_ i: Int) -> Color {
        if i < completedCount           { return .green }
        if i == currentIndex && !isFinished { return .accentColor }
        return Color(.tertiarySystemBackground)
    }

    // MARK: - Challenge body

    private var challengeBody: some View {
        VStack(spacing: 16) {
            header
            targetCard
                .padding(.horizontal)
            DrawingCanvas(canvasView: $canvasView)
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal)
            actionRow
                .padding(.horizontal)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 12)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("第 \(currentIndex + 1) / \(totalCharacters) 个")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.textSecondary)
                Text("用手指在下方画出这个假名")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            timerPill
    }

    private var timerPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
            Text("\(timeRemaining)s")
                .font(.caption.monospacedDigit().weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(timeRemaining <= 5 ? Color.red.opacity(0.18) : Color.accentColor.opacity(0.15),
                    in: Capsule())
        .foregroundStyle(timeRemaining <= 5 ? .red : .accentColor)
        .animation(.easeInOut(duration: 0.2), value: timeRemaining)
    }

    private var targetCard: some View {
        VStack(spacing: 4) {
            Text(currentCharacter ?? "")
                .font(.system(size: 160, weight: .light, design: .serif))
                .foregroundStyle(.primary)
                .frame(minHeight: 200)
                .accessibilityIdentifier("target-kana")
            Text("对照上方字形，在下方画一画")
                .font(.footnote)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                advance(counted: false)
            } label: {
                Label("跳过", systemImage: "forward.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)

            Button {
                advance(counted: canvasHasContent)
            } label: {
                Label("完成", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canvasHasContent)
        }
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: completedCount >= 8 ? "trophy.fill" : "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(completedCount >= 8 ? .yellow : .accentColor)
                .symbolEffect(.bounce, value: completedCount)
            Text("挑战结束")
                .font(.title.bold())
            Text("\(completedCount) / \(totalCharacters) 完成")
                .font(.title3.monospacedDigit())
                .foregroundStyle(Color.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                label("学新进度", value: "\(goal.learnedToday) / \(DailyGoalStore.dailyLearnTarget)")
                label("用时", value: durationText)
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 32)

            Button {
                dismiss()
            } label: {
                Text("回到学习")
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Button("再玩一次") {
                startSession()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }

    private func label(_ text: String, value: String) -> some View {
        HStack {
            Text(text)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
        }
    }

    // MARK: - Logic

    private var currentCharacter: String? {
        guard currentIndex < pool.count else { return nil }
        return pool[currentIndex]
    }

    private var canvasHasContent: Bool {
        !canvasView.drawing.bounds.isEmpty
    }

    private var durationText: String {
        let seconds = Int(Date().timeIntervalSince(sessionStartedAt))
        let m = seconds / 60
        let s = seconds % 60
        return m > 0 ? "\(m) 分 \(s) 秒" : "\(s) 秒"
    }

    private func startSession() {
        let shuffled = hiraganaBank.shuffled().prefix(totalCharacters)
        pool = Array(shuffled)
        currentIndex = 0
        completedCount = 0
        isFinished = false
        sessionStartedAt = Date()
        canvasView.drawing = PKDrawing()
        startTimer()
    }

    private func startTimer() {
        timerTask?.cancel()
        timeRemaining = secondsPerCharacter
        timerTask = Task {
            while !Task.isCancelled, timeRemaining > 0, !isFinished {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if timeRemaining > 0 { timeRemaining -= 1 }
                    if timeRemaining == 0 { advance(counted: false) }
                }
            }
        }
    }

    private func advance(counted: Bool) {
        if counted, canvasHasContent {
            completedCount += 1
            goal.recordLearned()
        }
        canvasView.drawing = PKDrawing()
        if currentIndex + 1 >= totalCharacters {
            finish(commit: true)
        } else {
            currentIndex += 1
            startTimer()
        }
    }

    private func finish(commit: Bool) {
        timerTask?.cancel()
        isFinished = true
        _ = commit
    }
}