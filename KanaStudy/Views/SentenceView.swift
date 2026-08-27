import SwiftUI

struct SentenceListView: View {
    @State private var items: [SentenceItem] = []
    @State private var error: String?

    var body: some View {
        List(items) { item in
            NavigationLink {
                SentenceDetailView(item: item)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.jp)
                        .font(.body.weight(.medium))
                    if let reading = item.reading {
                        Text(reading)
                            .font(.footnote)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("例句 · \(items.count)")
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
        do { items = try ContentService.shared.loadSentences() }
        catch { self.error = "\(error)" }
    }
}

struct SentenceDetailView: View {
    let item: SentenceItem
    @State private var playing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.jp)
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .padding(.top)

                if let reading = item.reading {
                    Text(reading)
                        .font(.title3)
                        .foregroundStyle(Color.textSecondary)
                }

                HStack(spacing: 12) {
                    Button {
                        AudioService.shared.speak(text: item.jp, language: "ja-JP")
                    } label: {
                        Label("朗读", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        AudioService.shared.speak(text: item.jp, language: "ja-JP", rate: 0.4)
                    } label: {
                        Label("慢速", systemImage: "tortoise.fill")
                    }
                    .buttonStyle(.bordered)
                }

                if let zh = item.zh {
                    Divider()
                    Text(zh)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
            .padding()
        }
        .navigationTitle("例句")
        .navigationBarTitleDisplayMode(.inline)
    }
}