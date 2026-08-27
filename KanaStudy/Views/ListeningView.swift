import SwiftUI

struct ListeningListView: View {
    @State private var items: [ListeningItem] = []
    @State private var error: String?

    var body: some View {
        List(items) { item in
            NavigationLink {
                ListeningDetailView(item: item)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.transcript)
                        .font(.footnote)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("听力 · \(items.count)")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if let error {
                ContentUnavailableView("加载失败", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if items.isEmpty {
                ProgressView()
            }
        }
        .task { await load() }
    }

    private func load() async {
        do { items = try ContentService.shared.loadListening() }
        catch { self.error = "\(error)" }
    }
}

struct ListeningDetailView: View {
    let item: ListeningItem
    @State private var revealed = false
    @State private var selectedAnswer: String?

    private var isCorrect: Bool { selectedAnswer == item.answer }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.title)
                    .font(.title.bold())

                HStack {
                    Button {
                        AudioService.shared.speak(text: item.transcript, language: "ja-JP")
                    } label: {
                        Label("播放原文", systemImage: "play.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        AudioService.shared.speak(text: item.transcript, language: "ja-JP", rate: 0.5)
                    } label: {
                        Label("慢速", systemImage: "tortoise.fill")
                    }
                    .buttonStyle(.bordered)
                }

                if revealed {
                    Text(item.transcript)
                        .font(.body)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }

                Divider()

                Text(item.question)
                    .font(.headline)

                ForEach(item.options, id: \.self) { option in
                    Button {
                        guard !revealed else { return }
                        selectedAnswer = option
                        revealed = true
                    } label: {
                        HStack {
                            Text(option).foregroundStyle(.primary)
                            Spacer()
                            if revealed {
                                if option == item.answer {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                } else if option == selectedAnswer {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                }
                            }
                        }
                        .padding()
                        .background(buttonBackground(for: option), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(revealed)
                }

                if revealed, let translation = item.translation {
                    Divider()
                    Text(translation)
                        .font(.body)
                        .foregroundStyle(Color.textSecondary)
                }

                if revealed {
                    Text(isCorrect ? "正确" : "正确答案是：\(item.answer)")
                        .font(.headline)
                        .foregroundStyle(isCorrect ? .green : .red)
                }
            }
            .padding()
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buttonBackground(for option: String) -> Color {
        guard revealed else { return Color(.tertiarySystemBackground) }
        if option == item.answer { return Color.green.opacity(0.2) }
        if option == selectedAnswer { return Color.red.opacity(0.2) }
        return Color(.tertiarySystemBackground)
    }
}