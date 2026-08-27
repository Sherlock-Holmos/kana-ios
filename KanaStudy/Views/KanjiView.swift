import SwiftUI

struct KanjiListView: View {
    @State private var items: [KanjiItem] = []
    @State private var error: String?

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 10)]

    var body: some View {
        ScrollView {
            if let error {
                ContentUnavailableView("加载失败", systemImage: "exclamationmark.triangle", description: Text(error))
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { item in
                    NavigationLink {
                        KanjiDetailView(item: item)
                    } label: {
                        KanjiTile(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("汉字 · \(items.count)")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if items.isEmpty && error == nil { ProgressView() } }
        .task { await load() }
    }

    private func load() async {
        do { items = try await ContentService.shared.loadKanji() }
        catch { self.error = "\(error)" }
    }
}

private struct KanjiTile: View {
    let item: KanjiItem

    var body: some View {
        VStack(spacing: 4) {
            Text(item.character)
                .font(.system(size: 36, weight: .medium, design: .serif))
            if !item.primaryMeaning.isEmpty {
                Text(item.primaryMeaning)
                    .font(.caption2)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 72, height: 84)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct KanjiDetailView: View {
    let item: KanjiItem
    @State private var showFurigana = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(item.character)
                    .font(.system(size: 96, weight: .medium, design: .serif))
                    .padding(.top, 24)

                if !item.primaryMeaning.isEmpty {
                    Text(item.primaryMeaning)
                        .font(.title2)
                }

                if !item.kunReadings.isEmpty {
                    readings("训读", readings: item.kunReadings)
                }
                if !item.onReadings.isEmpty {
                    readings("音读", readings: item.onReadings)
                }

                if let examples = item.examples, !examples.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("例字").font(.headline)
                        ForEach(examples, id: \.self) { ex in
                            Text(ex)
                                .font(.title3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding()
        }
        .navigationTitle(item.character)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func readings(_ title: String, readings: [String]) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Text(readings.joined(separator: " · "))
                .font(.body.monospaced())
                .foregroundStyle(Color.textSecondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}