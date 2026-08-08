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
    @Published var appearance = Preferences.appearance
    @Published var reasoningEffort = Preferences.reasoningEffort
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var busy = false

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
            async let user = api.currentUser()
            async let loadedProfiles = api.profiles()
            currentUser = try await user
            profiles = try await loadedProfiles
            selectProfileIfNeeded()
            phase = .signedIn
            await StudioLogoStore.shared.sync(from: api)
        } catch {
            if case HermesError.http(401, _) = error { SecureStore.remove("token"); token = "" }
            phase = .signedOut
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

    func setLanguage(_ value: String) { language = value; Preferences.language = value }
    func setAppearance(_ value: String) { appearance = value; Preferences.appearance = value }
    func setReasoning(_ value: String) { reasoningEffort = value; Preferences.reasoningEffort = value }

    func notify(_ text: String) { successMessage = text; Task { try? await Task.sleep(for: .seconds(2)); if self.successMessage == text { self.successMessage = nil } } }

    private func selectProfileIfNeeded() {
        if profiles.contains(where: { $0.name == selectedProfile }) { return }
        selectedProfile = profiles.first(where: \.active)?.name ?? profiles.first?.name ?? "default"
        Preferences.profile = selectedProfile
    }
}
