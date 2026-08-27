import SwiftUI

struct GrammarListView: View {
    @State private var items: [GrammarItem] = []
    @State private var error: String?

    var body: some View {
        List(items) { item in
            NavigationLink {
                GrammarDetailView(item: item)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.pattern)
                        .font(.headline)
                    if !item.primaryMeaning.isEmpty {
                        Text(item.primaryMeaning)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("语法 · \(items.count)")
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
        do { items = try ContentService.shared.loadGrammar() }
        catch { self.error = "\(error)" }
    }
}

struct GrammarDetailView: View {
    let item: GrammarItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.pattern)
                    .font(.largeTitle.bold())

                if !item.primaryMeaning.isEmpty {
                    Label(item.primaryMeaning, systemImage: "lightbulb.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                }

                if let explanation = item.explanation, !explanation.isEmpty {
                    section("说明", body: explanation)
                }

                if let formation = item.formation, !formation.isEmpty {
                    section("构成", body: formation.joined(separator: " · "))
                }

                if let tags = item.tags, !tags.isEmpty {
                    Text(tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
        }
        .navigationTitle(item.pattern)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(body)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}