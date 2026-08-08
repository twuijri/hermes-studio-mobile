import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var store: AppStore
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""
    @FocusState private var focused: Field?
    enum Field { case server, username, password }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    VStack(spacing: 14) {
                        AppMark(size: 88).shadow(color: HermesTheme.purple.opacity(0.24), radius: 24, y: 10)
                        Text("Hermes Studio").font(.largeTitle.bold())
                        Text("Your Studio, native on iPhone").font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.top, 50)

                    VStack(spacing: 14) {
                        field("Studio address", icon: "server.rack", text: $server, field: .server, contentType: .URL)
                            .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        field("Username", icon: "person", text: $username, field: .username, contentType: .username)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        HStack(spacing: 12) {
                            Image(systemName: "lock").foregroundStyle(.secondary).frame(width: 22)
                            SecureField("Password", text: $password).textContentType(.password).focused($focused, equals: .password).submitLabel(.go).onSubmit(login)
                        }.padding(.horizontal, 15).frame(height: 54).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                        Button(action: login) {
                            HStack { if store.busy { ProgressView().tint(.white) }; Text(store.busy ? "Connecting…" : "Connect").fontWeight(.semibold) }
                                .frame(maxWidth: .infinity).frame(height: 52)
                        }.buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 16)).disabled(!valid || store.busy)
                    }
                    SurfaceCard {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lock.shield.fill").foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 4) { Text("Private and direct").font(.subheadline.weight(.semibold)); Text("The app connects straight to your Hermes Studio. Your access token is kept in the iPhone Keychain.").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }.padding(.horizontal, 22).padding(.bottom, 30)
            }.hermesBackground()
        }.onAppear { server = store.baseURL }
    }

    private var valid: Bool { !server.trimmingCharacters(in: .whitespaces).isEmpty && !username.isEmpty && !password.isEmpty }
    private func login() { focused = nil; Task { await store.login(server: server, username: username, password: password) } }

    private func field(_ title: LocalizedStringKey, icon: String, text: Binding<String>, field: Field, contentType: UITextContentType) -> some View {
        HStack(spacing: 12) { Image(systemName: icon).foregroundStyle(.secondary).frame(width: 22); TextField(title, text: text).textContentType(contentType).focused($focused, equals: field).submitLabel(field == .password ? .go : .next).onSubmit { focused = field == .server ? .username : .password } }
            .padding(.horizontal, 15).frame(height: 54).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
