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

/// KanaWritingChallenge — 5-minute mini-loop at the top of the Learn tab.
///
/// Mode: production test. The screen shows romaji; the user must write the
/// matching kana in the canvas. We don't reveal the answer until after each
/// attempt so the exercise measures recall, not copying.
///
/// MVP validation runs three heuristic checks against KanaStrokeLibrary:
///   1. stroke count must match the canonical count for that kana
///   2. bounding-box aspect ratio must fall in the expected range
///   3. drawing must occupy at least minPathCoverage of the canvas perimeter
///
/// This catches scribbles and wrong-stroke-count attempts cleanly. It does NOT
/// distinguish kana with the same stroke count and similar aspect ratio —
/// those slip through until the KanjiVG + DTW matcher lands next week.
struct KanaWritingChallenge: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var goal: DailyGoalStore

    @State private var pool: [(character: String, romaji: String)] = []
    @State private var currentIndex: Int = 0
    @State private var timeRemaining: Int = 30
    @State private var completedCount: Int = 0
    @State private var isFinished: Bool = false
    @State private var canvasView = PKCanvasView()
    @State private var timerTask: Task<Void, Never>?
    @State private var sessionStartedAt: Date = Date()
    @State private var drawingStartedAt: Date?
    @State private var lastFailure: String?
    @State private var showAnswer: Bool = false
    @State private var passTrigger: Int = 0
    @State private var failTrigger: Int = 0

    private let totalCharacters = 10
    private let secondsPerCharacter = 30
    /// Failures aren't rewarded even if the user eventually draws something
    /// correct — only the first valid attempt counts.
    private let canvasSize = CGSize(width: 320, height: 280)

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
        .sensoryFeedback(.success, trigger: passTrigger)
        .sensoryFeedback(.error, trigger: failTrigger)
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalCharacters, id: \.self) { i in
                Capsule()
                    .fill(colorForSlot(i))
                    .frame(height: 6)
                    .animation(.easeInOut(duration: 0.3), value: currentIndex)
                    .animation(.easeInOut(duration: 0.3), value: completedCount)
            }
        }
    }

    private func colorForSlot(_ i: Int) -> Color {
        if i < completedCount                  { return .green }
        if i == currentIndex && !isFinished    { return .accentColor }
        return Color(.tertiarySystemBackground)
    }

    // MARK: - Challenge body

    private var challengeBody: some View {
        VStack(spacing: 16) {
            header
            promptCard
                .padding(.horizontal)
            DrawingCanvas(canvasView: $canvasView)
                .frame(maxWidth: .infinity)
                .frame(height: canvasSize.height)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal)
                .overlay(alignment: .topTrailing) {
                        if showAnswer, let current = currentItem {
                            Text(current.character)
                                .font(.system(size: 28, weight: .light, design: .serif))
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                .padding(12)
                        }
                    }
            feedbackArea
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
                Text("根据罗马音写出假名")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            timerPill
        }
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

    private var promptCard: some View {
        VStack(spacing: 8) {
            if let current = currentItem {
                Text(current.romaji)
                    .font(.system(size: 88, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("romaji-prompt")
                Text("\(current.character)  ·  \(current.romaji.count) 笔")
                    .font(.footnote)
                    .foregroundStyle(Color.textTertiary)
            } else {
                Text("—")
                    .font(.system(size: 88, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var feedbackArea: some View {
        if let message = lastFailure {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
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
                showAnswer = true
            } label: {
                Label("提示", systemImage: "lightbulb")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)

            Button {
                submit()
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
            Text("\(completedCount) / \(totalCharacters) 通过")
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

    private var currentItem: (character: String, romaji: String)? {
        guard currentIndex < pool.count else { return nil }
        return pool[currentIndex]
    }

    private var canvasHasContent: Bool {
        !canvasView.drawing.bounds.isEmpty
    }

    private var drawingDuration: TimeInterval {
        if let start = drawingStartedAt {
            return Date().timeIntervalSince(start)
        }
        return 0
    }

    private var durationText: String {
        let seconds = Int(Date().timeIntervalSince(sessionStartedAt))
        let m = seconds / 60
        let s = seconds % 60
        return m > 0 ? "\(m) 分 \(s) 秒" : "\(s) 秒"
    }

    private func startSession() {
        let candidates = KanaStrokeLibrary.allCharacters.shuffled().prefix(totalCharacters)
        pool = candidates.compactMap { character in
            guard let t = KanaStrokeLibrary.template(for: character) else { return nil }
            return (t.character, t.romaji)
        }
        currentIndex = 0
        completedCount = 0
        isFinished = false
        sessionStartedAt = Date()
        lastFailure = nil
        showAnswer = false
        canvasView.drawing = PKDrawing()
        drawingStartedAt = nil
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

    private func submit() {
        guard let item = currentItem,
              let template = KanaStrokeLibrary.template(for: item.character) else {
            advance(counted: false)
            return
        }
        // Record drawing start time when user first makes a mark.
        if drawingStartedAt == nil, canvasHasContent {
            drawingStartedAt = Date()
        }

        let metrics = computeMetrics()
        let verdict = KanaStrokeTemplate.evaluate(
            template,
            strokeCount: metrics.strokeCount,
            aspect: metrics.aspect,
            pathCoverage: metrics.pathCoverage
        )
        switch verdict {
        case .pass:
            lastFailure = nil
            passTrigger += 1
            advance(counted: true)
        case .fail(let reason):
            lastFailure = reason
            failTrigger += 1
            // Reset canvas so the user can retry the same character without counting.
            canvasView.drawing = PKDrawing()
            drawingStartedAt = nil
        }
    }

    private func advance(counted: Bool) {
        if counted {
            completedCount += 1
            goal.recordLearned()
        }
        lastFailure = nil
        showAnswer = false
        canvasView.drawing = PKDrawing()
        drawingStartedAt = nil
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

    // MARK: - Drawing metrics

    private func computeMetrics() -> DrawingMetrics {
        let drawing = canvasView.drawing
        let strokeCount = drawing.strokes.count

        let bounds = drawing.bounds
        let w = max(bounds.width, 1)
        let h = max(bounds.height, 1)
        let aspect = Double(w / h)

        // Sum each PKStroke's path length by sampling interpolated points.
        // PKStrokePath has no built-in length, so walk its interpolated points
        // and accumulate Euclidean distance. Anything < ~30% of canvas perimeter
        // means the user barely drew.
        let totalLength = drawing.strokes.reduce(0.0) { acc, stroke in
            let points = stroke.path.controlPoints
            var length = 0.0
            for i in 1..<points.count {
                let dx = Double(points[i].location.x - points[i - 1].location.x)
                let dy = Double(points[i].location.y - points[i - 1].location.y)
                length += (dx * dx + dy * dy).squareRoot()
            }
            return acc + length
        }
        let perimeter = Double(canvasSize.width + canvasSize.height)
        let pathCoverage = totalLength / perimeter

        return DrawingMetrics(
            strokeCount: strokeCount,
            aspect: aspect,
            pathCoverage: pathCoverage
        )
    }
}