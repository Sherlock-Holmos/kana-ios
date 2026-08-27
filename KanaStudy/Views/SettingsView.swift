import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SyncSettings
    @EnvironmentObject private var sync: SyncService
    @EnvironmentObject private var goal: DailyGoalStore

    @State private var email = ""
    @State private var password = ""
    @State private var urlInput = ""
    @State private var keyInput = ""
    @State private var showAdvanced = false

    @State private var busy = false

    var body: some View {
        Form {
            Section {
                if let user = sync.currentUser {
                    HStack {
                        Text("已登录")
                        Spacer()
                        Text(user.email)
                            .foregroundStyle(.secondary)
                    }
                    Button("登出", role: .destructive) {
                        sync.signOut()
                    }
                } else if settings.isConfigured {
                    TextField("邮箱", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    SecureField("密码", text: $password)

                    HStack {
                        Button("登录") {
                            Task {
                                busy = true
                                await sync.signIn(email: email, password: password)
                                busy = false
                            }
                        }
                        .disabled(email.isEmpty || password.isEmpty || busy)

                        Spacer()

                        Button("注册") {
                            Task {
                                busy = true
                                await sync.signUp(email: email, password: password)
                                busy = false
                            }
                        }
                        .disabled(email.isEmpty || password.isEmpty || busy)
                    }
                } else {
                    Text("后端未配置")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("账号")
            } footer: {
                if settings.isConfigured {
                    Text("后端：\(settings.supabaseURL)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

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
            } header: {
                Text("云端同步")
            } footer: {
                Text("App 已默认连接到 kana-study Web 版相同的 Supabase 项目（公开 publishable key，开箱即用）。多设备登录同一账号自动同步学习数据。")
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

            Section("每日目标") {
                Stepper("每日复习目标：\(goal.dailyGoal)", value: Binding(
                    get: { goal.dailyGoal },
                    set: { goal.setGoal($0) }
                ), in: 5...200, step: 5)
            }

            Section("同步状态") {
                if let last = sync.lastSyncedAt {
                    HStack {
                        Text("上次同步")
                        Spacer()
                        Text(last.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("尚未同步").foregroundStyle(.secondary)
                }
                if let err = sync.lastError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if sync.isSyncing {
                    HStack { ProgressView(); Text("同步中…") }
                }
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            urlInput = settings.supabaseURL
            keyInput = settings.anonKey
            email = settings.userEmail
        }
    }
}