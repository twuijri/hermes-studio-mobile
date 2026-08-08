import SwiftUI

@main
struct HermesStudioApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                Group {
                    switch store.phase {
                    case .launching: LaunchView()
                    case .signedOut: LoginView()
                    case .signedIn: RootTabs()
                    }
                }
                if let error = store.errorMessage {
                    ErrorBanner(message: error).padding(.horizontal).padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity)).onTapGesture { store.errorMessage = nil }
                } else if let message = store.successMessage {
                    Label(message, systemImage: "checkmark.circle.fill").font(.footnote.weight(.medium)).foregroundStyle(.white).padding(11).background(.green.gradient, in: Capsule()).padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity))
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
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        VStack(spacing: 20) { AppMark(size: 94); ProgressView().controlSize(.large); Text("Hermes Studio").font(.title2.weight(.bold)) }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(HermesTheme.navy).foregroundStyle(.white)
    }
}
