import SwiftUI

struct HomeView: View {
    let onJump: (AppTab) -> Void

    @EnvironmentObject private var srs: SRSStore
    @EnvironmentObject private var ability: AbilityProfile
    @EnvironmentObject private var bkt: BKTStore
    @EnvironmentObject private var goal: DailyGoalStore
    @EnvironmentObject private var sync: SyncService

    @State private var recommendations: [Planner.Recommendation] = []
    @State private var loadError: String?
    @State private var showLoginSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    syncCard
                    DailyMissionCard(
                        onTapReview: { onJump(.review) },
                        onTapLearn:  { onJump(.learn) },
                        onTapListen: { onJump(.learn) }
                    )
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showLoginSheet) {
                LoginSheet()
            }
            .task { await load() }
        }
    }

    @ViewBuilder
    private var syncCard: some View {
        if let user = sync.currentUser {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("已同步").font(.subheadline.weight(.semibold))
                    Text(user.email)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Button("管理") { showLoginSheet = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        } else {
            Button {
                showLoginSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "icloud.and.arrow.up")
                        .foregroundStyle(.tint)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("未登录 · 登录以同步进度")
                            .font(.subheadline.weight(.semibold))
                        Text("多设备共享 SRS / BKT / 每日目标")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.textTertiary)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("每天 20 分钟，过 JLPT N5")
                .font(.headline)
                .foregroundStyle(Color.textSecondary)
            Text(greeting)
                .font(.largeTitle.bold())
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<11:  return "早上好"
        case 11..<14: return "中午好"
        case 14..<18: return "下午好"
        case 18..<22: return "晚上好"
        default:      return "夜深了"
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速进入")
                .font(.headline)
            Button { onJump(.learn) } label: {
                row(icon: "book.fill", title: "开始学习", subtitle: "假名 / 词汇 / 语法 / 汉字 / 例句 / 阅读 / 听力 / 跟读")
            }
            .buttonStyle(.plain)
            Button { onJump(.review) } label: {
                row(icon: "arrow.clockwise", title: "今日复习", subtitle: "SRS 间隔重复 · \(srs.dueItems().count) 张到期")
            }
            .buttonStyle(.plain)
        }
    }

    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BKT 自适应推荐")
                .font(.headline)
            if recommendations.isEmpty {
                Text("暂无推荐 — 去「学习」里走一遍即可生成。")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
            } else {
                ForEach(recommendations) { rec in
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.id.abilityDisplayName)
                                .font(.body.weight(.medium))
                            if rec.id != rec.id.abilityDisplayName {
                                Text(rec.id)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(Color.textTertiary)
                            }
                        }
                        Spacer()
                        Text(rec.reason)
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.accentColor)
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
                Text(subtitle).font(.caption).foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.textTertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func load() async {
        do {
            let kana = try await ContentService.shared.loadKana()
            let vocab = try await ContentService.shared.loadVocabulary()
            recommendations = Planner(srs: srs, bkt: bkt, goal: goal)
                .recommend(limit: 6, kana: kana, vocab: vocab)
            loadError = nil
        } catch {
            loadError = "内容加载失败：\(error)"
        }
    }
}