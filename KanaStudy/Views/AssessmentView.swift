import SwiftUI

struct AssessmentView: View {
    @State private var bank: [QuestionVariant] = []
    @State private var kana: [KanaItem] = []
    @State private var vocab: [VocabularyItem] = []
    @State private var prompts: [ExercisePrompt] = []
    @State private var index = 0
    @State private var selected: String?
    @State private var revealed = false
    @State private var correctCount = 0
    @State private var error: String?

    private var current: ExercisePrompt? {
        guard prompts.indices.contains(index) else { return nil }
        return prompts[index]
    }

    var body: some View {
        VStack(spacing: 16) {
            if let error {
                Text(error).foregroundStyle(.red)
            }

            progress

            if let p = current {
                promptCard(p)
                optionsList(p)
                if revealed {
                    feedbackRow(p)
                }
                nextButton
            } else if prompts.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                summary
            }

            Spacer()
        }
        .padding()
        .navigationTitle("阶段测验")
        .navigationBarTitleDisplayMode(.inline)
        .task { await prepare() }
    }

    private var progress: some View {
        VStack(spacing: 4) {
            HStack {
                Text("第 \(index + 1) / \(prompts.count) 题")
                Spacer()
                Text("正确 \(correctCount)")
                    .foregroundStyle(.green)
            }
            .font(.caption.monospacedDigit())
            ProgressView(value: Double(index), total: Double(max(prompts.count, 1)))
        }
    }

    private func promptCard(_ p: ExercisePrompt) -> some View {
        VStack(spacing: 10) {
            Text(p.prompt)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .padding()
            Text("Skill: \(p.skill)")
                .font(.caption2)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func optionsList(_ p: ExercisePrompt) -> some View {
        VStack(spacing: 8) {
            ForEach(p.options, id: \.self) { option in
                Button {
                    guard !revealed else { return }
                    selected = option
                    revealed = true
                    if option == p.correctAnswer { correctCount += 1 }
                } label: {
                    HStack {
                        Text(option).foregroundStyle(.primary)
                        Spacer()
                        if revealed {
                            if option == p.correctAnswer {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            } else if option == selected {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                            }
                        }
                    }
                    .padding()
                    .background(buttonBackground(for: option, prompt: p), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(revealed)
            }
        }
    }

    private func feedbackRow(_ p: ExercisePrompt) -> some View {
        let correct = selected == p.correctAnswer
        return Text(correct ? "正确" : "正确答案：\(p.correctAnswer)")
            .font(.headline)
            .foregroundStyle(correct ? .green : .red)
    }

    private var nextButton: some View {
        Button {
            revealed = false
            selected = nil
            index += 1
        } label: {
            Text(index == prompts.count - 1 ? "完成" : "下一题")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!revealed)
    }

    private var summary: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("测验结束")
                .font(.title.bold())
            Text("\(correctCount) / \(prompts.count) 正确")
                .font(.title2)
            Button("再来一次") {
                Task { await prepare() }
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 32)
    }

    private func buttonBackground(for option: String, prompt: ExercisePrompt) -> Color {
        guard revealed else { return Color(.tertiarySystemBackground) }
        if option == prompt.correctAnswer { return Color.green.opacity(0.2) }
        if option == selected { return Color.red.opacity(0.2) }
        return Color(.tertiarySystemBackground)
    }

    private func prepare() async {
        do {
            bank = try ContentService.shared.loadQuestionBank()
            kana = try ContentService.shared.loadKana()
            vocab = try ContentService.shared.loadVocabulary()
            let session = ExerciseEngine.shared.sessionSample(bank: bank, count: 10)
            prompts = session.compactMap { variant in
                ExerciseEngine.shared.makeExercise(for: variant, kana: kana, vocab: vocab)
            }
            index = 0
            correctCount = 0
            revealed = false
            selected = nil
            error = nil
        } catch {
            self.error = "测验准备失败：\(error)"
        }
    }
}