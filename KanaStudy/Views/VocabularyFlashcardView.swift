import SwiftUI

struct VocabularyFlashcardView: View {
    @EnvironmentObject private var srsStore: SRSStore

    @State private var items: [VocabularyItem] = []
    @State private var index: Int = 0
    @State private var revealed: Bool = false
    @State private var error: String?
    @State private var enrollTrigger = 0

    private var current: VocabularyItem? {
        guard items.indices.contains(index) else { return nil }
        return items[index]
    }

    var body: some View {
        VStack(spacing: 16) {
            if let error {
                ErrorView(error, retry: { Task { await load() } })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let current {
                card(for: current)
                    .padding(.horizontal)

                controls
                    .padding(.horizontal)

                if revealed {
                    enrollButton(current)
                        .padding(.horizontal)
                }
            } else {
                ProgressView("加载中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer()
        }
        .padding(.vertical)
        .navigationTitle("词汇")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sensoryFeedback(.impact(weight: .medium), trigger: enrollTrigger)
    }

    private func card(for item: VocabularyItem) -> some View {
        VStack(spacing: 12) {
            Text(item.expression)
                .font(.system(size: 56, weight: .medium, design: .serif))
            Text(item.reading)
                .font(.title3)
                .foregroundStyle(Color.textSecondary)
            HStack(spacing: 8) {
                Button {
                    AudioService.shared.speak(text: item.expression, language: "ja-JP")
                } label: {
                    Label("朗读", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
            }
            if revealed {
                Divider().padding(.vertical, 8)
                Text(item.primaryMeaning)
                    .font(.title3.bold())
                if item.meanings.count > 1 {
                    Text(item.meanings.dropFirst().joined(separator: "；"))
                        .font(.footnote)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                if let pos = item.partOfSpeech {
                    Text(pos)
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                        .padding(.top, 4)
                }
            } else {
                Button("显示释义") { revealed = true }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func enrollButton(_ item: VocabularyItem) -> some View {
        Button {
            srsStore.enroll(item.id)
            enrollTrigger += 1
        } label: {
            Label("加入复习", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button {
                prev()
            } label: {
                Label("上一张", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(index <= 0)

            Text("\(index + 1) / \(items.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.textSecondary)

            Button {
                next()
            } label: {
                Label("下一张", systemImage: "chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(items.isEmpty || index >= items.count - 1)
        }
    }

    private func next() {
        guard index < items.count - 1 else { return }
        index += 1
        revealed = false
    }

    private func prev() {
        guard index > 0 else { return }
        index -= 1
        revealed = false
    }

    private func load() async {
        do {
            items = try await ContentService.shared.loadVocabulary()
            error = nil
        } catch {
            self.error = "词汇加载失败：\(error)"
        }
    }
}