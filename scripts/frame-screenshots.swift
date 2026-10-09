// Renders App Store marketing frames from raw simulator captures.
// Palette and type come from the app: the icon's ink and paper (scripts/render-icon.swift),
// Theme.aqua's dark-mode mint, SF Pro headlines and the tracked uppercase eyebrow used on the
// medication card.
//
//   swiftc -parse-as-library scripts/frame-screenshots.swift -o build/frame-screenshots
//   build/frame-screenshots build/screenshots/raw fastlane/screenshots/en-US build/screenshots/overview.png
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct Shot {
    let screen: String
    var appearance = "light"
    let eyebrow: String
    let headline: String
    let subtitle: String
}

/// Order is the App Store order; the first three carry the listing. Subtitles break by hand so lines balance.
let shots = [
    Shot(screen: "home", eyebrow: "Dose & weight journal", headline: "A calm journal\nfor your treatment.", subtitle: "Doses, weight and progress together,\nkept privately on your iPhone."),
    Shot(screen: "progress", eyebrow: "Progress", headline: "See how far\nyou've come.", subtitle: "Your weight trend, goal and weekly\nchange, drawn from your own entries."),
    Shot(screen: "log-dose", eyebrow: "Logging", headline: "Log a dose\nin seconds.", subtitle: "The amount in mg, the time and\nan optional note. Nothing more."),
    Shot(screen: "journal", eyebrow: "Journal", headline: "Your history,\nday by day.", subtitle: "Every dose and weigh-in in one tidy\ntimeline that is easy to edit."),
    Shot(screen: "settings", eyebrow: "Privacy", headline: "Private\nby design.", subtitle: "No account and no servers.\nApple Health weight is read-only."),
    Shot(screen: "home", appearance: "dark", eyebrow: "Light & dark", headline: "Easy on the eyes,\nday or night.", subtitle: "Tendr follows your iPhone's light\nor dark appearance."),
]

let canvas = CGSize(width: 1320, height: 2868)

enum Palette {
    static let ink = Color(white: 0.055)
    static let paper = Color(white: 0.95)
    static let muted = Color(white: 0.63)
    static let mint = Color(red: 0.39, green: 0.84, blue: 0.73)
    static let aqua = Color(red: 0.02, green: 0.46, blue: 0.43)
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            Palette.ink
            RadialGradient(colors: [Palette.aqua.opacity(0.85), Palette.aqua.opacity(0.25), .clear], center: UnitPoint(x: 0.5, y: 0.62), startRadius: 0, endRadius: 1250)
            RadialGradient(colors: [Palette.mint.opacity(0.10), .clear], center: UnitPoint(x: 0.5, y: 0.02), startRadius: 0, endRadius: 820)
        }
    }
}

/// A modern iPhone with a titanium rim, black bezel and Dynamic Island, sized by its screen width.
struct Device: View {
    let screen: NSImage
    let width: CGFloat
    var body: some View {
        let height = width * screen.size.height / screen.size.width
        let bezel = width * 0.03
        let rim = width * 0.008
        let screenRadius = width * 0.141
        let outer = CGSize(width: width + bezel * 2, height: height + bezel * 2)
        ZStack {
            RoundedRectangle(cornerRadius: screenRadius + bezel, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.42), Color(white: 0.17), Color(white: 0.30), Color(white: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: screenRadius + bezel - rim, style: .continuous)
                .fill(Color.black)
                .padding(rim)
            Image(nsImage: screen).resizable().interpolation(.high)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: screenRadius, style: .continuous))
            Capsule().fill(Color.black)
                .frame(width: width * 0.286, height: width * 0.084)
                .position(x: outer.width / 2, y: bezel + width * 0.026 + width * 0.042)
        }
        .frame(width: outer.width, height: outer.height)
        .background(alignment: .topLeading) { buttons(outer: outer, rim: rim) }
        .shadow(color: .black.opacity(0.55), radius: 70, y: 40)
    }

    private func buttons(outer: CGSize, rim: CGFloat) -> some View {
        let fill = LinearGradient(colors: [Color(white: 0.36), Color(white: 0.16)], startPoint: .leading, endPoint: .trailing)
        let depth = rim * 0.9
        func key(_ x: CGFloat, _ top: CGFloat, _ length: CGFloat) -> some View {
            RoundedRectangle(cornerRadius: depth).fill(fill)
                .frame(width: depth * 2, height: outer.height * length)
                .offset(x: x, y: outer.height * top)
        }
        return ZStack(alignment: .topLeading) {
            key(-depth, 0.165, 0.035)
            key(-depth, 0.225, 0.062)
            key(-depth, 0.302, 0.062)
            key(outer.width - depth, 0.255, 0.095)
            key(outer.width - depth, 0.505, 0.055)
        }
    }
}

struct Frame: View {
    let shot: Shot
    let screen: NSImage
    var body: some View {
        ZStack(alignment: .top) {
            Backdrop()
            VStack(spacing: 0) {
                Text(shot.eyebrow.uppercased())
                    .font(.system(size: 32, weight: .bold))
                    .tracking(5.1)
                    .foregroundStyle(Palette.mint)
                Text(shot.headline)
                    .font(.system(size: 112, weight: .bold))
                    .tracking(-1.6)
                    .lineSpacing(2)
                    .foregroundStyle(Palette.paper)
                    .padding(.top, 34)
                Text(shot.subtitle)
                    .font(.system(size: 44, weight: .regular))
                    .lineSpacing(8)
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: 1060)
                    .padding(.top, 34)
                Device(screen: screen, width: 1100)
                    .padding(.top, 84)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 148)
            .frame(width: canvas.width, height: canvas.height, alignment: .top)
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
    }
}

struct Overview: View {
    let frames: [NSImage]
    var body: some View {
        HStack(spacing: 48) {
            ForEach(frames.indices, id: \.self) { index in
                Image(nsImage: frames[index]).resizable().interpolation(.high)
                    .frame(width: 440, height: 956)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        }
        .padding(80)
        .background(Color(white: 0.16))
    }
}

/// Writes an opaque sRGB PNG: App Store Connect rejects screenshots with an alpha channel.
@MainActor func render(_ view: some View, size: CGSize, to url: URL) throws {
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = 1
    renderer.proposedSize = ProposedViewSize(size)
    guard let image = renderer.cgImage,
          let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { throw CocoaError(.fileWriteUnknown) }
    context.draw(image, in: CGRect(origin: .zero, size: size))
    guard let opaque = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(destination, opaque, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

@main struct FrameScreenshots {
    @MainActor static func main() throws {
        let arguments = CommandLine.arguments.dropFirst()
        let raw = URL(fileURLWithPath: arguments.first ?? "build/screenshots/raw")
        let output = URL(fileURLWithPath: arguments.dropFirst().first ?? "fastlane/screenshots/en-US")
        let overview = arguments.dropFirst(2).first.map { URL(fileURLWithPath: $0) }
        let files = FileManager.default
        try files.createDirectory(at: output, withIntermediateDirectories: true)
        for stale in try files.contentsOfDirectory(at: output, includingPropertiesForKeys: nil) where stale.pathExtension == "png" {
            try files.removeItem(at: stale)
        }
        var framed: [NSImage] = []
        for (index, shot) in shots.enumerated() {
            let source = raw.appendingPathComponent(shot.appearance).appendingPathComponent("\(shot.screen).png")
            guard let screen = NSImage(contentsOf: source) else { throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: source.path]) }
            let name = shot.appearance == "light" ? shot.screen : "\(shot.screen)-\(shot.appearance)"
            let destination = output.appendingPathComponent(String(format: "%02d-%@.png", index + 1, name))
            try render(Frame(shot: shot, screen: screen), size: canvas, to: destination)
            framed.append(NSImage(contentsOf: destination)!)
            print("Framed \(destination.path)")
        }
        if let overview {
            try files.createDirectory(at: overview.deletingLastPathComponent(), withIntermediateDirectories: true)
            let size = CGSize(width: 80 * 2 + 440 * CGFloat(framed.count) + 48 * CGFloat(framed.count - 1), height: 80 * 2 + 956)
            try render(Overview(frames: framed), size: size, to: overview)
            print("Overview \(overview.path)")
        }
    }
}
