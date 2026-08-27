import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SyncSettings
    @EnvironmentObject private var sync: SyncService

    @State private var email = ""
    @State private var password = ""
    @State private var urlInput = ""
    @State private var keyInput = ""

    @State private var busy = false

    var body: some View {
        Form {
            Section("云端同步（可选）") {
                Text("填入 Supabase 项目 URL + anon key 开启多设备同步。留空 = 完全本地模式，所有功能可用。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("https://xxx.supabase.co", text: $urlInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                SecureField("anon / public key", text: $keyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack {
                    Text("Schema 版本")
                    Spacer()
                    Stepper("\(settings.schemaVersion)", value: $settings.schemaVersion, in: 12...16)
                }

                Button("保存") {
                    settings.supabaseURL = urlInput.trimmingCharacters(in: .whitespaces)
                    settings.anonKey = keyInput.trimmingCharacters(in: .whitespaces)
                }
                .disabled(urlInput.isEmpty && keyInput.isEmpty)

                if settings.isConfigured {
                    Button("清除", role: .destructive) {
                        settings.reset()
                        urlInput = ""
                        keyInput = ""
                    }
                }
            }

            Section("账号") {
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
                    Text("填入 URL + key 后启用登录")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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

            Section {
                Text("需要在 Supabase 控制台创建表 user_learning_meta (user_id uuid PK, schema_version int, meta jsonb, updated_at timestamptz)，并配置 RLS 允许当前用户读写自己的行。详见仓库 README。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Supabase 配置说明")
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