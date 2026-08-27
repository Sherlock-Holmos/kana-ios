import SwiftUI

struct ReadingListView: View {
    @State private var items: [ReadingItem] = []
    @State private var error: String?

    var body: some View {
        List(items) { item in
            NavigationLink {
                ReadingDetailView(item: item)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.passage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("阅读 · \(items.count)")
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
        do { items = try ContentService.shared.loadReading() }
        catch { self.error = "\(error)" }
    }
}

struct ReadingDetailView: View {
    let item: ReadingItem
    @State private var selectedAnswer: String?
    @State private var revealed = false

    private var isCorrect: Bool { selectedAnswer == item.answer }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.title)
                    .font(.title.bold())

                Text(item.passage)
                    .font(.body)
                    .lineSpacing(4)

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
                            Text(option)
                                .foregroundStyle(.primary)
                            Spacer()
                            if revealed {
                                if option == item.answer {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else if option == selectedAnswer {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
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
                        .foregroundStyle(.secondary)
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