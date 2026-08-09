import SwiftUI

@main
struct HermesStudioApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                Group {
                    switch store.phase {
                    case .launching: LaunchView(server: store.baseURL)
                    case .signedOut: LoginView()
                    case .signedIn: RootTabs()
                    }
                }
                if let error = store.errorMessage {
                    ErrorBanner(message: error).padding(.horizontal).padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity)).onTapGesture { store.errorMessage = nil }
                } else if let message = store.successMessage {
                    Label(message, systemImage: "checkmark.circle.fill").font(.footnote.weight(.medium)).foregroundStyle(.white).padding(11).background(.green.gradient, in: Capsule()).padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity))
                }
                if store.languageTransitioning {
                    Color(uiColor: .systemBackground)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(100)
                        .accessibilityHidden(true)
                }
            }
            .environmentObject(store)
            .environment(\.locale, store.locale)
            .environment(\.layoutDirection, store.layoutDirection)
            .preferredColorScheme(store.preferredColorScheme)
            .tint(HermesTheme.purple)
            .task { await store.boot() }
            .animation(.snappy, value: store.errorMessage)
            .animation(.snappy, value: store.successMessage)
            .animation(.easeInOut(duration: 0.11), value: store.languageTransitioning)
        }
    }
}

private struct LaunchView: View {
    let server: String

    var body: some View {
        VStack(spacing: 14) {
            AppMark(size: 94)
            Text("Hermes Studio").font(.title2.weight(.bold))
            if !server.isEmpty {
                Text(server)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            ProgressView().controlSize(.large).padding(.top, 5)
        }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(HermesTheme.navy).foregroundStyle(.white)
    }
}
