import SwiftUI

/// OnboardingView — 3-screen first-run experience, gated behind a UserDefaults flag.
/// Shown the first time the app launches and dismissed once the user taps "开始".
/// Models the Apple Fitness+ style: one concrete promise per screen, a single CTA at the end.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page: Int = 0
    @State private var showLogin = false

    private let totalPages = 3

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                hero(
                    systemImage: "sparkles",
                    tint: .indigo,
                    title: "每天 20 分钟，",
                    titleAccent: "过 JLPT N5",
                    body: "按 N5 大纲自适应推荐内容，AI 帮你挑选最该学、最该复习的卡。"
                )
                .tag(0)

                hero(
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: .blue,
                    title: "学 → 复习 → 进度",
                    titleAccent: "三步闭环",
                    body: "新内容自动加入 SRS 间隔重复，BKT 模型实时追踪每个能力的掌握度。"
                )
                .tag(1)

                hero(
                    systemImage: "icloud.fill",
                    tint: .teal,
                    title: "开启云同步",
                    titleAccent: "多设备无缝接续",
                    body: "登录后，进度自动同步到云端。换手机、换平板，学习数据不丢。"
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageDots
                .padding(.top, 8)

            cta
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showLogin) {
            LoginSheet()
        }
    }

    // MARK: - Hero

    private func hero(systemImage: String, tint: Color, title: String, titleAccent: String, body: String) -> some View {
        VStack(spacing: 28) {
            Spacer(minLength: 32)
            Image(systemName: systemImage)
                .font(.system(size: 96, weight: .light))
                .foregroundStyle(tint)
                .symbolEffect(.bounce, options: .repeat(.periodic(delay: 2.5)), value: page)
                .padding(.bottom, 8)

            VStack(spacing: 10) {
                Text(title)
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(titleAccent)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(tint)
                    .multilineTextAlignment(.center)
            }

            Text(body)
                .font(.body)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .lineSpacing(4)

            Spacer()
        }
    }

    // MARK: - Dots

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Color.accentColor : Color(.tertiarySystemBackground))
                    .frame(width: i == page ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: page)
            }
        }
    }

    // MARK: - CTA

    private var cta: some View {
        VStack(spacing: 12) {
            if page == 2 {
                Button {
                    showLogin = true
                } label: {
                    Label("登录同步账号", systemImage: "person.crop.circle.badge.plus")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("跳过，先开始学习") {
                    OnboardingGate.markCompleted()
                    onFinish()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.textSecondary)
                .font(.callout)
            } else {
                Button {
                    withAnimation { page += 1 }
                } label: {
                    Text("继续")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .onChange(of: showLogin) { _, new in
            if !new && page == 2 {
                // Login sheet dismissed; close onboarding too.
                OnboardingGate.markCompleted()
                onFinish()
            }
        }
    }
}

/// Tiny wrapper around UserDefaults to remember whether onboarding has been shown.
enum OnboardingGate {
    private static let flagKey = "kana-study.onboarding.completed"

    static var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: flagKey)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: flagKey)
    }
}