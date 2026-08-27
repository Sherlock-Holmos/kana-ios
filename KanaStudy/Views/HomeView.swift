import SwiftUI

struct HomeView: View {
    let onJump: (AppTab) -> Void

    @EnvironmentObject private var srs: SRSStore
    @EnvironmentObject private var ability: AbilityProfile

    @State private var counts: ContentService.Counts?
    @State private var recommendations: [Planner.Recommendation] = []
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if let counts { countsCard(counts) }
                    quickActions
                    recommendationsCard
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
                stat("阅读", c.reading)
                stat("听力", c.listening)
                stat("题目变体", c.questionVariants)
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
                row(icon: "book.fill", title: "开始学习", subtitle: "假名 / 词汇 / 语法 / 汉字 / 例句 / 阅读 / 听力")
            }
            .buttonStyle(.plain)
            Button { onJump(.review) } label: {
                row(icon: "arrow.clockwise", title: "复习", subtitle: "SRS 间隔重复 · \(srs.dueItems().count) 张到期")
            }
            .buttonStyle(.plain)
            Button { onJump(.library) } label: {
                row(icon: "books.vertical.fill", title: "浏览内容库", subtitle: "全部 7 类内容")
            }
            .buttonStyle(.plain)
        }
    }

    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("自适应推荐")
                .font(.headline)
            if recommendations.isEmpty {
                Text("暂无推荐 — 去「学习」里走一遍即可生成。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recommendations) { rec in
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.tint)
                        Text(rec.id)
                            .font(.body.monospaced())
                        Spacer()
                        Text(rec.reason)
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.tint.opacity(0.15), in: Capsule())
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
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
            let kana = try ContentService.shared.loadKana()
            let vocab = try ContentService.shared.loadVocabulary()
            recommendations = Planner(srs: srs, ability: ability)
                .recommend(limit: 6, kana: kana, vocab: vocab)
            loadError = nil
        } catch {
            loadError = "内容加载失败：\(error)"
        }
    }
}

extension Color {
    static let tint = Color.accentColor
}