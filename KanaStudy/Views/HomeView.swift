import SwiftUI

struct HomeView: View {
    let onJump: (AppTab) -> Void

    @State private var counts: ContentService.Counts?
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if let counts {
                        countsCard(counts)
                    }

                    quickActions

                    if let loadError {
                        Text(loadError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Spacer(minLength: 24)
                }
                .padding()
            }
            .navigationTitle("日语学习")
            .task { await load() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("N5 自适应学习系统")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("开始今天的学习")
                .font(.largeTitle.bold())
        }
    }

    private func countsCard(_ c: ContentService.Counts) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("当前内容规模")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                stat("假名", c.kana)
                stat("词汇", c.vocabulary)
                stat("语法", c.grammar)
                stat("汉字", c.kanji)
                stat("例句", c.sentence)
                stat("合计", c.kana + c.vocabulary + c.grammar + c.kanji + c.sentence)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速进入")
                .font(.headline)
            Button { onJump(.learn) } label: {
                row(icon: "book.fill", title: "开始学习", subtitle: "假名 / 词汇 / 语法")
            }
            .buttonStyle(.plain)

            Button { onJump(.review) } label: {
                row(icon: "arrow.clockwise", title: "复习", subtitle: "SRS 间隔重复")
            }
            .buttonStyle(.plain)

            Button { onJump(.library) } label: {
                row(icon: "books.vertical.fill", title: "浏览内容库", subtitle: "全部假名 / 词汇 / 语法 / 汉字 / 例句")
            }
            .buttonStyle(.plain)
        }
    }

    private func row(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func load() async {
        do {
            counts = try ContentService.shared.counts()
            loadError = nil
        } catch {
            loadError = "内容加载失败：\(error)"
        }
    }
}