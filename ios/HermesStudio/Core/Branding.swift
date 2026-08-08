import CryptoKit
import Foundation
import SwiftUI
import UIKit
import WebKit

@MainActor
final class StudioLogoStore: ObservableObject {
    static let shared = StudioLogoStore()

    @Published private(set) var image: UIImage?

    private let refreshInterval: TimeInterval = 7 * 24 * 60 * 60
    private var didLoadCache = false

    private init() {}

    func loadCached() async {
        guard !didLoadCache else { return }
        didLoadCache = true
        let file = Self.logoFile
        let data = await Task.detached(priority: .utility) { try? Data(contentsOf: file) }.value
        if let data, let decoded = UIImage(data: data) { image = decoded }
    }

    func sync(from api: APIClient, force: Bool = false) async {
        await loadCached()
        let file = Self.logoFile
        let serverFile = Self.serverFile
        let server = api.baseURL
        let refreshInterval = refreshInterval
        let fresh = await Task.detached(priority: .utility) {
            guard !force,
                  FileManager.default.fileExists(atPath: file.path),
                  (try? String(contentsOf: serverFile, encoding: .utf8)) == server,
                  let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate
            else { return false }
            return Date().timeIntervalSince(modified) < refreshInterval
        }.value
        guard !fresh, let data = await api.logoData(), let decoded = UIImage(data: data) else { return }

        await Task.detached(priority: .utility) {
            try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
            try? server.write(to: serverFile, atomically: true, encoding: .utf8)
        }.value
        image = decoded
    }

    nonisolated private static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HermesStudio/branding", isDirectory: true)
    }
    nonisolated private static var logoFile: URL { directory.appendingPathComponent("studio-logo") }
    nonisolated private static var serverFile: URL { directory.appendingPathComponent("studio-logo.server") }
}

@MainActor
final class AvatarImageCache: ObservableObject {
    static let shared = AvatarImageCache()

    @Published private var images: [String: UIImage] = [:]
    private var loadedFingerprints: [String: String] = [:]
    private var loading: Set<String> = []

    private init() {}

    func image(for profile: String) -> UIImage? { images[profile] }

    func ensure(profile: String, avatar: AvatarSpec?) async {
        guard !profile.isEmpty else { return }
        let fingerprint = avatarFingerprint(profile: profile, avatar: avatar)
        guard loadedFingerprints[profile] != fingerprint, !loading.contains(profile) else { return }
        loading.insert(profile)

        if let cached = await Task.detached(priority: .utility, operation: {
            AvatarDiskCache.cached(profile: profile, fingerprint: fingerprint)
        }).value {
            images[profile] = cached
            loadedFingerprints[profile] = fingerprint
            loading.remove(profile)
            return
        }

        let result: UIImage?
        if avatar?.type == "image", let dataURL = avatar?.dataURL {
            result = await Task.detached(priority: .utility) {
                AvatarDiskCache.decodeDataURL(dataURL)
            }.value
        } else if let markup = await Task.detached(priority: .utility, operation: {
            MultiAvatar.svg(seed: avatar?.seed ?? profile)
        }).value {
            result = await SVGSnapshotRenderer.shared.render(markup)
        } else {
            result = nil
        }

        if let result {
            await Task.detached(priority: .utility) {
                AvatarDiskCache.store(result, profile: profile, fingerprint: fingerprint)
            }.value
            images[profile] = result
            loadedFingerprints[profile] = fingerprint
        }
        loading.remove(profile)
    }
}

func avatarFingerprint(profile: String, avatar: AvatarSpec?) -> String {
    if avatar?.type == "image", let dataURL = avatar?.dataURL {
        return "image:\(avatar?.updatedAt ?? 0):\(sha256(dataURL))"
    }
    return "generated:\(avatar?.seed ?? profile)"
}

private enum AvatarDiskCache {
    static func cached(profile: String, fingerprint: String) -> UIImage? {
        let files = files(profile: profile)
        guard (try? String(contentsOf: files.stamp, encoding: .utf8)) == fingerprint else { return nil }
        return UIImage(contentsOfFile: files.image.path)
    }

    static func store(_ image: UIImage, profile: String, fingerprint: String) {
        let files = files(profile: profile)
        guard let png = image.pngData() else { return }
        try? png.write(to: files.image, options: .atomic)
        try? fingerprint.write(to: files.stamp, atomically: true, encoding: .utf8)
    }

    static func decodeDataURL(_ value: String) -> UIImage? {
        guard let comma = value.firstIndex(of: ","),
              let data = Data(base64Encoded: String(value[value.index(after: comma)...]), options: .ignoreUnknownCharacters)
        else { return nil }
        return UIImage(data: data)
    }

    private static func files(profile: String) -> (image: URL, stamp: URL) {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HermesStudio/avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let key = sha256(profile)
        return (
            directory.appendingPathComponent("\(key).png"),
            directory.appendingPathComponent("\(key).stamp")
        )
    }
}

enum MultiAvatar {
    private static let order = ["env", "clo", "head", "mouth", "eyes", "top"]

    static func svg(seed: String) -> String? {
        guard let url = Bundle.main.url(forResource: "multiavatar", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let source = try? JSONSerialization.jsonObject(with: data) as? JSON,
              let themes = source["themes"] as? JSON,
              let parts = source["parts"] as? JSON
        else { return nil }

        let digits = selectedDigits(seed)
        var rendered: [String: String] = [:]
        for (index, part) in order.enumerated() {
            guard let value = Int(digits.dropFirst(index * 2).prefix(2)) else { return nil }
            let scaled = Int((0.47 * Double(value)).rounded())
            let version: String
            let theme: String
            if scaled > 31 { version = padded(scaled - 32); theme = "C" }
            else if scaled > 15 { version = padded(scaled - 16); theme = "B" }
            else { version = padded(scaled); theme = "A" }

            guard let versionThemes = themes[version] as? JSON,
                  let selectedTheme = versionThemes[theme] as? JSON,
                  let colors = selectedTheme[part] as? [String],
                  let versionParts = parts[version] as? JSON,
                  let markup = versionParts[part] as? String
            else { return nil }
            rendered[part] = painted(markup, colors: colors)
        }

        return source.string("svgStart")
            + (rendered["env"] ?? "") + (rendered["head"] ?? "") + (rendered["clo"] ?? "")
            + (rendered["top"] ?? "") + (rendered["eyes"] ?? "") + (rendered["mouth"] ?? "")
            + source.string("svgEnd")
    }

    private static func selectedDigits(_ seed: String) -> String {
        let digest = SHA256.hash(data: Data(seed.utf8)).map { String(format: "%02x", $0) }.joined()
        return String((digest.filter(\.isNumber) + String(repeating: "0", count: 12)).prefix(12))
    }

    private static func padded(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }

    private static func painted(_ markup: String, colors: [String]) -> String {
        guard let regex = try? NSRegularExpression(pattern: "#.*?;") else { return markup }
        let range = NSRange(markup.startIndex..<markup.endIndex, in: markup)
        let matches = Array(regex.matches(in: markup, range: range).prefix(colors.count))
        var result = markup
        for (match, color) in zip(matches, colors).reversed() {
            guard let swiftRange = Range(match.range, in: result) else { continue }
            result.replaceSubrange(swiftRange, with: color + ";")
        }
        return result
    }
}

@MainActor
private final class SVGSnapshotRenderer {
    static let shared = SVGSnapshotRenderer()
    private var jobs: [UUID: SVGRenderJob] = [:]

    func render(_ markup: String, pixels: CGFloat = 288) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let id = UUID()
            let job = SVGRenderJob(markup: markup, pixels: pixels) { [weak self] image in
                self?.jobs.removeValue(forKey: id)
                continuation.resume(returning: image)
            }
            jobs[id] = job
            job.start()
        }
    }
}

@MainActor
private final class SVGRenderJob: NSObject, WKNavigationDelegate {
    private let markup: String
    private let webView: WKWebView
    private var completion: ((UIImage?) -> Void)?

    init(markup: String, pixels: CGFloat, completion: @escaping (UIImage?) -> Void) {
        self.markup = markup
        self.completion = completion
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: pixels, height: pixels), configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
    }

    func start() {
        let html = """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>html,body{margin:0;padding:0;width:100%;height:100%;overflow:hidden;background:transparent}svg{display:block;width:100%;height:100%}</style>
        </head><body>\(markup)</body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async { [weak self] in self?.snapshot() }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(nil) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(nil) }

    private func snapshot() {
        let configuration = WKSnapshotConfiguration()
        configuration.rect = webView.bounds
        webView.takeSnapshot(with: configuration) { [weak self] image, _ in self?.finish(image) }
    }

    private func finish(_ image: UIImage?) {
        guard let completion else { return }
        self.completion = nil
        completion(image)
    }
}

private func sha256(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
}
