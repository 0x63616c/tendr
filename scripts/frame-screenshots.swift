// Frames raw simulator captures into App Store marketing screenshots (1320x2868, 6.9" iPhone).
// Usage: swift scripts/frame-screenshots.swift <raw-dir> <output-dir>
// Palette and type come from the app: Theme in Still/StillApp.swift and the icon in scripts/render-icon.swift.
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct Shot {
    let source: String
    let output: String
    let eyebrow: String
    let headline: (String, String)
    let subtitle: String
    let dark: Bool
}

let shots = [
    Shot(source: "01-home", output: "01_home", eyebrow: "TODAY", headline: ("Your week,", "at a glance."),
         subtitle: "Your next dose, an estimated level and your weight on one calm screen.", dark: false),
    Shot(source: "02-progress", output: "02_progress", eyebrow: "PROGRESS", headline: ("See how far", "you've come."),
         subtitle: "Trends, goals and weekly change from the weights you log.", dark: false),
    Shot(source: "03-journal", output: "03_journal", eyebrow: "JOURNAL", headline: ("Every dose.", "Every weigh-in."),
         subtitle: "A simple record of what you took and when, in mg.", dark: false),
    Shot(source: "04-home-dark", output: "04_dark_mode", eyebrow: "DAY AND NIGHT", headline: ("Calm by day.", "Calm by night."),
         subtitle: "A quiet, focused design with a full dark mode.", dark: true),
    Shot(source: "05-privacy-dark", output: "05_privacy", eyebrow: "PRIVACY", headline: ("Private", "by design."),
         subtitle: "No account, no ads, no servers. Your journal stays on your iPhone.", dark: true),
]

enum Palette {
    static let ink = Color(white: 0.055)            // icon background
    static let paper = Color(white: 0.95)           // icon glyph
    static let mist = Color(red: 0.96, green: 0.96, blue: 0.98) // Theme.background (light)
    static let aquaLight = Color(red: 0.02, green: 0.46, blue: 0.43) // Theme.aqua (light)
    static let aquaDark = Color(red: 0.39, green: 0.84, blue: 0.73)  // Theme.aqua (dark)
}

let canvas = CGSize(width: 1320, height: 2868)
let screenSize = CGSize(width: 1320, height: 2868)

struct Background: View {
    let dark: Bool
    var accent: Color { dark ? Palette.aquaDark : Palette.aquaLight }
    var body: some View {
        ZStack {
            (dark ? Palette.ink : Palette.mist)
            RadialGradient(colors: [accent.opacity(dark ? 0.22 : 0.16), accent.opacity(0)], center: UnitPoint(x: 0.5, y: 0.62), startRadius: 0, endRadius: 1150)
            if !dark {
                LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.3))
            }
            // Ripples on still water, centred behind the device.
            ForEach(0..<6) { ring in
                Circle()
                    .stroke(dark ? Color.white.opacity(0.045) : accent.opacity(0.09), lineWidth: 2)
                    .frame(width: CGFloat(760 + ring * 420), height: CGFloat(760 + ring * 420))
                    .position(x: canvas.width / 2, y: 1780)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
    }
}

struct Device: View {
    let screenshot: NSImage
    let screenHeight: CGFloat
    let dark: Bool
    var scale: CGFloat { screenHeight / screenSize.height }
    var screenWidth: CGFloat { screenSize.width * scale }
    var screenRadius: CGFloat { 180 * scale }
    let bezel: CGFloat = 22
    let band: CGFloat = 7
    var outerWidth: CGFloat { screenWidth + 2 * (bezel + band) }
    var outerHeight: CGFloat { screenHeight + 2 * (bezel + band) }

    var titanium: LinearGradient {
        LinearGradient(colors: dark
                       ? [Color(white: 0.42), Color(white: 0.2), Color(white: 0.32), Color(white: 0.18)]
                       : [Color(white: 0.36), Color(white: 0.14), Color(white: 0.26), Color(white: 0.12)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    func button(_ length: CGFloat, at fraction: CGFloat, leading: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(titanium)
            .frame(width: 9, height: length)
            .position(x: leading ? -3 : outerWidth + 3, y: outerHeight * fraction + length / 2)
    }

    var body: some View {
        ZStack {
            button(70, at: 0.165, leading: true)
            button(120, at: 0.235, leading: true)
            button(120, at: 0.315, leading: true)
            button(190, at: 0.255, leading: false)
            button(95, at: 0.56, leading: false)
            RoundedRectangle(cornerRadius: screenRadius + bezel + band, style: .continuous)
                .fill(titanium)
                .overlay(
                    RoundedRectangle(cornerRadius: screenRadius + bezel + band, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.08), .white.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2.5)
                )
                .frame(width: outerWidth, height: outerHeight)
                .position(x: outerWidth / 2, y: outerHeight / 2)
            RoundedRectangle(cornerRadius: screenRadius + bezel, style: .continuous)
                .fill(Color.black)
                .frame(width: screenWidth + 2 * bezel, height: screenHeight + 2 * bezel)
                .position(x: outerWidth / 2, y: outerHeight / 2)
            Image(nsImage: screenshot)
                .resizable()
                .interpolation(.high)
                .frame(width: screenWidth, height: screenHeight)
                .clipShape(RoundedRectangle(cornerRadius: screenRadius, style: .continuous))
                .position(x: outerWidth / 2, y: outerHeight / 2)
            Capsule()
                .fill(Color.black)
                .frame(width: 378 * scale, height: 112 * scale)
                .position(x: outerWidth / 2, y: band + bezel + 33 * scale + 56 * scale)
        }
        .frame(width: outerWidth, height: outerHeight)
        .shadow(color: dark ? Palette.aquaDark.opacity(0.16) : Color.black.opacity(0.22), radius: dark ? 90 : 60, y: dark ? 0 : 36)
    }
}

struct Frame: View {
    let shot: Shot
    let screenshot: NSImage
    var accent: Color { shot.dark ? Palette.aquaDark : Palette.aquaLight }
    var ink: Color { shot.dark ? Palette.paper : Palette.ink }
    var body: some View {
        ZStack(alignment: .top) {
            Background(dark: shot.dark)
            VStack(spacing: 0) {
                Text(shot.eyebrow)
                    .font(.system(size: 30, weight: .bold))
                    .tracking(5)
                    .foregroundStyle(accent)
                    .padding(.bottom, 34)
                VStack(spacing: 2) {
                    Text(shot.headline.0).foregroundStyle(ink)
                    Text(shot.headline.1).foregroundStyle(accent)
                }
                .font(.system(size: 112, weight: .bold))
                .tracking(-2.5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.bottom, 30)
                Text(shot.subtitle)
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(ink.opacity(shot.dark ? 0.66 : 0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .frame(width: 1060)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 168)
            Device(screenshot: screenshot, screenHeight: 2040, dark: shot.dark)
                .position(x: canvas.width / 2, y: 2868 - 66 - (2040 + 58) / 2)
        }
        .frame(width: canvas.width, height: canvas.height)
        .environment(\.colorScheme, shot.dark ? .dark : .light)
    }
}

func writeOpaquePNG(_ image: CGImage, to url: URL) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(data: nil, width: Int(canvas.width), height: Int(canvas.height), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw CocoaError(.fileWriteUnknown) }
    context.draw(image, in: CGRect(origin: .zero, size: canvas))
    guard let flattened = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(destination, flattened, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: frame-screenshots.swift <raw-dir> <output-dir>\n".utf8))
    exit(64)
}
let rawDirectory = URL(fileURLWithPath: arguments[1])
let outputDirectory = URL(fileURLWithPath: arguments[2])
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
for stale in try FileManager.default.contentsOfDirectory(at: outputDirectory, includingPropertiesForKeys: nil) where stale.pathExtension == "png" {
    try FileManager.default.removeItem(at: stale)
}

try MainActor.assumeIsolated {
    for shot in shots {
        let source = rawDirectory.appendingPathComponent("\(shot.source).png")
        guard let screenshot = NSImage(contentsOf: source) else { throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: source.path]) }
        let renderer = ImageRenderer(content: Frame(shot: shot, screenshot: screenshot))
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(canvas)
        guard let image = renderer.cgImage, image.width == Int(canvas.width), image.height == Int(canvas.height) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSLocalizedDescriptionKey: "Rendering \(shot.output) failed"])
        }
        let destination = outputDirectory.appendingPathComponent("\(shot.output).png")
        try writeOpaquePNG(image, to: destination)
        print("Framed \(destination.path)")
    }
}
