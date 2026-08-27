import SwiftUI

struct KanaBrowserView: View {
    @State private var items: [KanaItem] = []
    @State private var error: String?

    private var hiragana: [KanaItem] { items.filter { $0.isHiragana } }
    private var katakana: [KanaItem] { items.filter { $0.isKatakana } }

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 10)]

    var body: some View {
        List {
            if let error {
                Text(error).foregroundStyle(.red)
            }
            section(title: "平假名 · \(hiragana.count)", items: hiragana)
            section(title: "片假名 · \(katakana.count)", items: katakana)
        }
        .navigationTitle("假名")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func section(title: String, items: [KanaItem]) -> some View {
        Section(title) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { item in
                    KanaTile(item: item)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func load() async {
        do {
            items = try ContentService.shared.loadKana()
            error = nil
        } catch {
            self.error = "假名加载失败：\(error)"
        }
    }
}

private struct KanaTile: View {
    let item: KanaItem
    @State private var showRoman = false

    var body: some View {
        Button {
            showRoman.toggle()
        } label: {
            VStack(spacing: 4) {
                Text(item.kana)
                    .font(.system(size: 32, weight: .medium, design: .serif))
                Text(showRoman ? item.roman : "·")
                    .font(.caption2)
                    .foregroundStyle(showRoman ? .primary : .secondary)
            }
            .frame(width: 64, height: 64)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}