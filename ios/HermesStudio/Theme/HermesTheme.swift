import SwiftUI

enum HermesTheme {
    static let purple = Color(red: 0.396, green: 0.278, blue: 0.961)
    static let navy = Color(red: 0.035, green: 0.067, blue: 0.145)
    static let cyan = Color(red: 0.20, green: 0.72, blue: 0.92)
    static let green = Color(red: 0.24, green: 0.78, blue: 0.47)
    static let amber = Color(red: 0.96, green: 0.64, blue: 0.20)
    static let radius: CGFloat = 18
}

struct AppMark: View {
    var size: CGFloat = 58
    @ObservedObject private var logo = StudioLogoStore.shared

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.07, green: 0.11, blue: 0.23), HermesTheme.navy], startPoint: .topLeading, endPoint: .bottomTrailing))
            if let image = logo.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Canvas { context, canvas in
                    let scale = canvas.width / 108
                    func line(_ points: [CGPoint]) {
                        var path = Path(); guard let first = points.first else { return }; path.move(to: CGPoint(x: first.x * scale, y: first.y * scale))
                        for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.x * scale, y: point.y * scale)) }
                        context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 9 * scale, lineCap: .round, lineJoin: .round))
                    }
                    line([.init(x: 54, y: 24), .init(x: 54, y: 47)])
                    line([.init(x: 38, y: 38), .init(x: 38, y: 52), .init(x: 25, y: 63)])
                    line([.init(x: 70, y: 38), .init(x: 70, y: 52), .init(x: 83, y: 63)])
                    line([.init(x: 31, y: 76), .init(x: 50, y: 64), .init(x: 58, y: 64), .init(x: 77, y: 76)])
                    let dot = CGRect(x: 48 * scale, y: 48 * scale, width: 12 * scale, height: 12 * scale)
                    context.fill(Path(ellipseIn: dot), with: .color(HermesTheme.purple))
                }
                .padding(size * 0.04)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
        .accessibilityLabel("Hermes Studio")
        .task { await logo.loadCached() }
    }
}

struct ProfileAvatar: View {
    let name: String
    var avatar: AvatarSpec?
    var size: CGFloat = 42
    @ObservedObject private var cache = AvatarImageCache.shared

    var body: some View {
        Group {
            if let image = cache.image(for: name) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(initials).font(.system(size: size * 0.34, weight: .bold, design: .rounded)).foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
        .task(id: avatarFingerprint(profile: name, avatar: avatar)) {
            await cache.ensure(profile: name, avatar: avatar)
        }
    }

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased().nilIfEmpty ?? "H"
    }
    private var colors: [Color] {
        let palette: [[Color]] = [[HermesTheme.purple, .indigo], [.teal, .cyan], [.orange, .pink], [.blue, .purple], [.green, .teal]]
        return palette[abs(name.hashValue) % palette.count]
    }
}

struct SurfaceCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(16).background(.thinMaterial, in: RoundedRectangle(cornerRadius: HermesTheme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HermesTheme.radius, style: .continuous).stroke(.primary.opacity(0.07)))
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    var body: some View { Text(text).font(.caption2.weight(.semibold)).padding(.horizontal, 9).padding(.vertical, 5).foregroundStyle(color).background(color.opacity(0.13), in: Capsule()) }
}

struct ToolIcon: View {
    let name: String
    var body: some View {
        Image(systemName: symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(color).frame(width: 34, height: 34).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
    private var symbol: String {
        let key = name.lowercased()
        if key.contains("terminal") || key.contains("shell") { return "terminal" }
        if key.contains("vision") || key.contains("image") { return "eye" }
        if key.contains("search") || key.contains("web") { return "magnifyingglass" }
        if key.contains("file") || key.contains("read") || key.contains("write") { return "doc.text" }
        if key.contains("browser") { return "globe" }
        if key.contains("python") || key.contains("code") { return "chevron.left.forwardslash.chevron.right" }
        return "wrench.and.screwdriver"
    }
    private var color: Color { name.lowercased().contains("terminal") ? .green : HermesTheme.purple }
}

extension View {
    func hermesBackground() -> some View { background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea()) }
}
