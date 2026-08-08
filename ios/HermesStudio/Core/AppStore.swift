import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var phase: Phase = .launching
    @Published var baseURL = Preferences.baseURL
    @Published var token = SecureStore.get("token")
    @Published var currentUser: CurrentUser?
    @Published var profiles: [Profile] = []
    @Published var selectedProfile = Preferences.profile
    @Published var language = Preferences.language
    @Published private(set) var languageRefresh = 0
    @Published var appearance = Preferences.appearance
    @Published var reasoningEffort = Preferences.reasoningEffort
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var busy = false

    private var languageRefreshTask: Task<Void, Never>?

    let api: APIClient

    enum Phase { case launching, signedOut, signedIn }

    init() { api = APIClient(baseURL: Preferences.baseURL, token: SecureStore.get("token")) }

    var locale: Locale {
        language == "ar" ? Locale(identifier: "ar") : (language == "en" ? Locale(identifier: "en") : .autoupdatingCurrent)
    }
    var layoutDirection: LayoutDirection { locale.language.languageCode?.identifier == "ar" ? .rightToLeft : .leftToRight }
    var preferredColorScheme: ColorScheme? { appearance == "dark" ? .dark : (appearance == "light" ? .light : nil) }
    var profile: Profile? { profiles.first { $0.name == selectedProfile } }
    var isConfigured: Bool { !baseURL.isEmpty && !token.isEmpty }

    func boot() async {
        await StudioLogoStore.shared.loadCached()
        guard isConfigured else { phase = .signedOut; return }
        api.update(baseURL: baseURL, token: token)
        do {
            // `/auth/me` is the authoritative credential check. A secondary
            // profile request must not turn a valid signed-in user into a login
            // screen during an update or a brief Studio restart.
            currentUser = try await api.currentUser()
            phase = .signedIn
            do {
                profiles = try await api.profiles()
            } catch {
                errorMessage = error.localizedDescription
            }
            selectProfileIfNeeded()
            await StudioLogoStore.shared.sync(from: api)
        } catch {
            // A development reinstall, a server restart, or one transient 401
            // must not destructively erase a valid Keychain credential. Only an
            // explicit Sign Out or a successful replacement login removes it.
            // This also lets the next launch retry without asking for the token.
            if case HermesError.http(401, _) = error {
                phase = .signedOut
            } else {
                // Keep the signed-in shell and the Keychain token on transient
                // connectivity failures. Lists can be refreshed after Studio
                // comes back instead of asking for credentials again.
                errorMessage = error.localizedDescription
                phase = .signedIn
            }
        }
    }

    func login(server: String, username: String, password: String) async {
        busy = true; errorMessage = nil
        var normalized = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.contains("://") { normalized = "https://" + normalized }
        normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        api.update(baseURL: normalized, token: "")
        do {
            let issued = try await api.login(username: username, password: password)
            baseURL = normalized; token = issued
            Preferences.baseURL = normalized; SecureStore.set(issued, for: "token")
            api.update(baseURL: normalized, token: issued)
            currentUser = try await api.currentUser()
            profiles = try await api.profiles()
            selectProfileIfNeeded()
            phase = .signedIn
            await StudioLogoStore.shared.sync(from: api)
        } catch { errorMessage = error.localizedDescription }
        busy = false
    }

    func refreshProfiles() async {
        do { profiles = try await api.profiles(); selectProfileIfNeeded() }
        catch { errorMessage = error.localizedDescription }
    }

    func chooseProfile(_ name: String) {
        selectedProfile = name; Preferences.profile = name
    }

    func signOut() {
        SecureStore.remove("token"); token = ""; currentUser = nil; profiles = []; phase = .signedOut
        api.update(baseURL: baseURL, token: "")
    }

    func updateServer(_ server: String) async {
        var normalized = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.contains("://") { normalized = "https://" + normalized }
        normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        baseURL = normalized; Preferences.baseURL = normalized; api.update(baseURL: normalized, token: token)
        await boot()
    }

    func setLanguage(_ value: String) {
        language = value
        Preferences.language = value

        // UIKit-backed SwiftUI Lists apply their RTL mirror one render pass
        // after the environment changes. Rebuild once more after that pass so
        // Arabic -> System/English cannot retain mirrored glyphs. A later
        // selection cancels the pending refresh instead of racing with it.
        languageRefreshTask?.cancel()
        languageRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            self?.languageRefresh &+= 1
        }
    }
    func setAppearance(_ value: String) { appearance = value; Preferences.appearance = value }
    func setReasoning(_ value: String) { reasoningEffort = value; Preferences.reasoningEffort = value }

    func notify(_ text: String) { successMessage = text; Task { try? await Task.sleep(for: .seconds(2)); if self.successMessage == text { self.successMessage = nil } } }

    private func selectProfileIfNeeded() {
        if profiles.contains(where: { $0.name == selectedProfile }) { return }
        selectedProfile = profiles.first(where: \.active)?.name ?? profiles.first?.name ?? "default"
        Preferences.profile = selectedProfile
    }
}
