import SwiftUI

struct HomeView: View {
    let onJump: (AppTab) -> Void

    @EnvironmentObject private var srs: SRSStore
    @EnvironmentObject private var goal: DailyGoalStore
    @EnvironmentObject private var sync: SyncService

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
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showLoginSheet) {
                LoginSheet()
            }
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
}