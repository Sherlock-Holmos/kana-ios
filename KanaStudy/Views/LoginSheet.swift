import SwiftUI

/// LoginSheet — modal sign-in / register / sign-out surface.
/// Shown from HomeView when the user isn't authenticated, and from Settings when
/// they want to manage their account.
struct LoginSheet: View {
    @EnvironmentObject private var sync: SyncService
    @EnvironmentObject private var settings: SyncSettings

    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var mode: Mode = .signIn
    @State private var busy: Bool = false
    @State private var successTrigger = 0
    @State private var errorTrigger = 0
    @State private var lastUserId: String?

    enum Mode: String, CaseIterable, Identifiable {
        case signIn = "登录"
        case signUp = "注册"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let user = sync.currentUser {
                    signedInSection(user: user)
                } else {
                    authSection
                }

                if let err = sync.lastError {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(sync.currentUser == nil ? "登录同步账号" : "账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                if email.isEmpty { email = settings.userEmail }
            }
            .onChange(of: sync.currentUser) { _, new in
                // Auto-dismiss after a fresh sign-in so the user lands back on Home.
                if new != nil, mode == .signIn {
                    dismiss()
                }
                if let id = new?.id, id != lastUserId {
                    successTrigger += 1
                    lastUserId = id
                } else if new == nil {
                    lastUserId = nil
                }
            }
            .onChange(of: sync.lastError) { _, new in
                if new != nil { errorTrigger += 1 }
            }
            .sensoryFeedback(.success, trigger: successTrigger)
            .sensoryFeedback(.error, trigger: errorTrigger)
        }
    }

    // MARK: - Sections

    private var authSection: some View {
        Group {
            Section {
                Picker("模式", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(busy)

                TextField("邮箱", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(busy)

                SecureField("密码（至少 6 位）", text: $password)
                    .textContentType(mode == .signIn ? .password : .newPassword)
                    .disabled(busy)
            } header: {
                Text("kana-study 云同步")
            } footer: {
                Text("使用邮箱即可在多设备间同步 SRS、BKT 掌握度、每日目标与热力图。默认连接 kana-study Web 版的 Supabase 项目。")
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        if busy { ProgressView().padding(.trailing, 4) }
                        Text(mode == .signIn ? "登录" : "注册并登录")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(busy || email.isEmpty || password.count < 6)
            }
        }
    }

    private func signedInSection(user: SyncUser) -> some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.email)
                        .font(.body.weight(.semibold))
                    Text("已登录")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)

            Button("登出", role: .destructive) {
                sync.signOut()
            }
        } footer: {
            Text("登录信息已保存在 iOS Keychain，杀进程后无需重新登录。")
        }
    }

    // MARK: - Actions

    private func submit() async {
        busy = true
        defer { busy = false }
        if mode == .signIn {
            await sync.signIn(email: email, password: password)
        } else {
            await sync.signUp(email: email, password: password)
        }
    }
}
