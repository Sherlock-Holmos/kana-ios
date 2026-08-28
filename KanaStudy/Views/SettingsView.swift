import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SyncSettings
    @EnvironmentObject private var sync: SyncService
    @EnvironmentObject private var goal: DailyGoalStore

    @State private var urlInput = ""
    @State private var keyInput = ""
    @State private var showAdvanced = false
    @State private var showLoginSheet = false

    var body: some View {
        Form {
            // MARK: Account (login lives in its own sheet)
            Section {
                if let user = sync.currentUser {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(.tint)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.email)
                                .font(.body.weight(.medium))
                            Text("已登录")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                    }
                    Button("管理账号") { showLoginSheet = true }
                } else {
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(Color.textTertiary)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("未登录")
                                .font(.body.weight(.medium))
                            Text("登录后可在多设备间同步进度")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                    }
                    Button("登录或注册") { showLoginSheet = true }
                        .buttonStyle(.borderedProminent)
                }
            } header: {
                Text("账号")
            }

            // MARK: Backend
            Section {
                if !settings.isUsingCustomBackend {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("已使用 kana-study 共享后端")
                        Spacer()
                    }
                    Button("切换到自定义后端") {
                        urlInput = settings.supabaseURL
                        keyInput = settings.anonKey
                        showAdvanced = true
                    }
                } else {
                    Button("恢复默认后端") {
                        settings.reset()
                        urlInput = ""
                        keyInput = ""
                    }
                }

                // Diagnostic banner — Supabase 2024+ ships a "publishable key" for
                // browser/API-gateway use, but PostgREST still expects the classic
                // `anon` JWT (`eyJ...`). Login via /auth/v1/token succeeds with
                // either format, but every subsequent /rest/v1 call 401s. Detect
                // the publishable prefix and surface the fix inline so the user
                // doesn't have to guess why signIn works but sync doesn't.
                if settings.anonKey.hasPrefix("sb_publishable_") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("anonKey 格式不被 PostgREST 接受")
                                .font(.subheadline.weight(.semibold))
                        }
                        Text("当前使用的是 publishable key (`sb_publishable_...`)，登录能成功，但同步请求会被服务端 401。")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                        Text("修复方法：")
                            .font(.caption.weight(.medium))
                        Text("1. 打开 Supabase Dashboard → Settings → API\n2. 复制 **anon / public** key（`eyJ...` 开头）\n3. 点上面的'切换到自定义后端'粘贴并保存")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                        if let projectRef = URL(string: settings.supabaseURL)?.host?
                            .components(separatedBy: ".").first {
                            Link("打开 \(projectRef) 的 API 设置",
                                 destination: URL(string: "https://supabase.com/dashboard/project/\(projectRef)/settings/api")!)
                                .font(.caption)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                }
            } header: {
                Text("云端同步")
            } footer: {
                Text("App 已默认连接到 kana-study Web 版相同的 Supabase 项目。多设备登录同一账号自动同步学习数据。")
            }

            if showAdvanced || settings.isUsingCustomBackend {
                Section("自定义 Supabase") {
                    TextField("https://xxx.supabase.co", text: $urlInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    SecureField("anon / publishable key", text: $keyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("保存") {
                        settings.supabaseURL = urlInput.trimmingCharacters(in: .whitespaces)
                        settings.anonKey = keyInput.trimmingCharacters(in: .whitespaces)
                    }
                    .disabled(urlInput.isEmpty && keyInput.isEmpty)
                }
            }

            // MARK: Daily goal
            Section("每日目标") {
                Stepper("每日复习目标：\(goal.dailyGoal)", value: Binding(
                    get: { goal.dailyGoal },
                    set: { goal.setGoal($0) }
                ), in: 5...200, step: 5)
            }

            // MARK: Sync status
            Section("同步状态") {
                if let last = sync.lastSyncedAt {
                    HStack {
                        Text("上次同步")
                        Spacer()
                        Text(last.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(Color.textSecondary)
                    }
                } else {
                    Text("尚未同步").foregroundStyle(Color.textSecondary)
                }
                if let err = sync.lastError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if sync.isSyncing {
                    HStack { ProgressView(); Text("同步中…") }
                }
                HStack {
                    Text("后端")
                    Spacer()
                    Text(settings.supabaseURL)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLoginSheet) {
            LoginSheet()
        }
        .onAppear {
            urlInput = settings.supabaseURL
            keyInput = settings.anonKey
        }
    }
}
