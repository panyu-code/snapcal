import SwiftUI
import AuthenticationServices

/// 登录页: Apple 登录 (主) + 开发模式登录 (调试)
struct LoginView: View {
    @EnvironmentObject private var app: AppModel
    @AppStorage("devUsername") private var devUsername = ""
    @State private var showDevLogin = false
    @State private var username = ""
    @State private var loading = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            Color.pageBG.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo 区
                VStack(spacing: 14) {
                    Text("📸").font(.system(size: 72))
                    Text("SnapCal").font(.largeTitle.bold())
                    Text("拍一下，吃明白")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 登录区
                VStack(spacing: 14) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName]
                    } onCompletion: { result in
                        handleApple(result)
                    }
                    .frame(height: 54)
                    .signInWithAppleButtonStyle(.white)

                    Button {
                        showDevLogin = true
                    } label: {
                        Text("开发模式登录 (调试)")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .underline()
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.footnote)
                            .foregroundStyle(.brandRed)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 60)
            }
        }
        .sheet(isPresented: $showDevLogin) {
            devLoginSheet
                .presentationDetents([.height(300)])
        }
    }

    // MARK: - 开发登录弹窗

    private var devLoginSheet: some View {
        VStack(spacing: 18) {
            Text("开发模式登录").font(.headline)
            Text("直连后端创建/进入测试账号").font(.caption).foregroundStyle(.secondary)

            TextField("用户名 (字母数字)", text: $username)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 24)

            Button {
                Task { await doDevLogin() }
            } label: {
                Group {
                    if loading { ProgressView().tint(.black) }
                    else { Text("登录").bold() }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.brandGreen)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(username.count < 2 || loading)
            .padding(.horizontal, 24)

            if let errorText {
                Text(errorText).font(.caption).foregroundStyle(.brandRed)
            }
        }
        .onAppear { username = devUsername }
    }

    // MARK: - 动作

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let auth) = result,
              let credential = auth.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            errorText = "Apple 登录失败"
            return
        }
        let fullName = [credential.fullName?.familyName, credential.fullName?.givenName]
            .compactMap { $0 }.joined()
        Task {
            do {
                try await app.appleLogin(identityToken: token, nickname: fullName.isEmpty ? nil : fullName)
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func doDevLogin() async {
        loading = true
        defer { loading = false }
        do {
            try await app.devLogin(username: username)
            showDevLogin = false
        } catch {
            self.errorText = error.localizedDescription
        }
    }
}
