#if DEBUG
import SwiftUI
import Observation
#if canImport(AppKit)
import AppKit
#endif

/// Development aid (Debug builds only): when launched with SIDDUR_SNAPSHOT_DIR set,
/// walks through the app's screens. On macOS it saves a PNG of its own window per
/// scenario. On iOS it writes `<name>.ready` into the directory and waits for a
/// `<name>.done` marker, so a shell loop can run `simctl io booted screenshot`.
@MainActor
@Observable
final class SnapshotDriver {
    static let shared = SnapshotDriver()

    let directory: String? = ProcessInfo.processInfo.environment["SIDDUR_SNAPSHOT_DIR"]
    var isEnabled: Bool { directory != nil }

    // State the views observe so the driver can open sheets and type queries.
    var showTypography = false
    var showSettings = false
    var searchQuery = ""
    var selectedRow: String?

    struct Scenario {
        let name: String
        let wait: Double
        let apply: @MainActor (RootView.Controls) -> Void
    }

    func run(controls: RootView.Controls) async {
        guard let directory else { return }
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let settings = ReadingSettings.shared
        let ashk = SiddurLibrary.root(for: .ashkenaz)
        let shacharit = ashk.descendant(titled: ["Weekday", "Shacharit"])!
        let modeh = ashk.descendant(titled: ["Weekday", "Shacharit", "Preparatory Prayers"])!
        let kabbalat = ashk.descendant(titled: ["Shabbat", "Kabbalat Shabbat"])!
        let ariShacharit = SiddurLibrary.root(for: .ari).descendant(titled: ["Shacharit"])!

        let scenarios: [Scenario] = [
            Scenario(name: "01-home-light", wait: 2.5) { c in
                settings.theme = .light; settings.nusach = .ashkenaz; settings.languageMode = .bilingual
                c.tab.wrappedValue = .today; c.todayPath.wrappedValue = []
            },
            Scenario(name: "02-home-dark", wait: 1.5) { _ in settings.theme = .dark },
            Scenario(name: "03-home-sepia", wait: 1.5) { _ in settings.theme = .sepia },
            Scenario(name: "04-library", wait: 1.5) { c in settings.theme = .light; c.tab.wrappedValue = .library },
            Scenario(name: "05-section-shacharit", wait: 1.5) { c in c.libraryPath.wrappedValue = [.section(.ashkenaz, shacharit.id)] },
            Scenario(name: "06-reader-bilingual", wait: 6) { c in
                c.tab.wrappedValue = .today; c.todayPath.wrappedValue = [.reader(.ashkenaz, modeh.id)]
            },
            Scenario(name: "06b-reader-bilingual-tap", wait: 1.5) { _ in self.selectedRow = "\(modeh.leaves[0].id)#1" },
            Scenario(name: "07-reader-hebrew", wait: 1.5) { _ in self.selectedRow = nil; settings.languageMode = .hebrew },
            Scenario(name: "07b-reader-hebrew-tap-reveal", wait: 1.5) { _ in self.selectedRow = "\(modeh.leaves[0].id)#1" },
            Scenario(name: "08-reader-english", wait: 1.5) { _ in settings.languageMode = .english },
            Scenario(name: "09-reader-stacked", wait: 1.5) { _ in self.selectedRow = nil; settings.languageMode = .bilingual; settings.bilingualLayout = .stacked },
            Scenario(name: "10-reader-large-david", wait: 1.5) { _ in
                settings.bilingualLayout = .automatic; settings.fontScale = 1.5; settings.hebrewFontID = "he.david"
            },
            Scenario(name: "11-reader-dark", wait: 1.5) { _ in settings.fontScale = 1.0; settings.hebrewFontID = "he.frank"; settings.theme = .dark },
            Scenario(name: "12-reader-no-nikud", wait: 1.5) { _ in settings.theme = .light; settings.showVowels = false },
            Scenario(name: "13-typography-sheet", wait: 2) { _ in settings.showVowels = true; self.showTypography = true },
            Scenario(name: "14-kabbalat-shabbat", wait: 6) { c in
                self.showTypography = false; c.todayPath.wrappedValue = [.reader(.ashkenaz, kabbalat.id)]
            },
            Scenario(name: "15-ari-hebrew-only", wait: 6) { c in
                settings.nusach = .ari; c.todayPath.wrappedValue = [.reader(.ari, ariShacharit.id)]
            },
            Scenario(name: "16-home-ari", wait: 1.5) { c in c.todayPath.wrappedValue = [] },
            Scenario(name: "17-home-sefard", wait: 1.5) { _ in settings.nusach = .sefard },
            Scenario(name: "18-search", wait: 2) { c in settings.nusach = .ashkenaz; c.tab.wrappedValue = .search; self.searchQuery = "kaddish" },
            Scenario(name: "19-settings", wait: 2) { c in c.tab.wrappedValue = .today; self.showSettings = true },
        ]

        try? await Task.sleep(for: .seconds(1.5))
        #if os(macOS)
        NSApp.activate()
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
        #endif
        for scenario in scenarios {
            withAnimation(nil) { scenario.apply(controls) }
            try? await Task.sleep(for: .seconds(scenario.wait))
            #if os(macOS)
            capture(named: scenario.name, into: directory)
            #else
            await signalAndWait(named: scenario.name, in: directory)
            #endif
        }
        #if os(macOS)
        NSApp.terminate(nil)
        #else
        FileManager.default.createFile(atPath: directory + "/ALL-DONE", contents: nil)
        #endif
    }

    #if !os(macOS)
    private func signalAndWait(named name: String, in directory: String) async {
        let ready = directory + "/" + name + ".ready"
        let done = directory + "/" + name + ".done"
        FileManager.default.createFile(atPath: ready, contents: nil)
        for _ in 0..<100 {
            if FileManager.default.fileExists(atPath: done) { return }
            try? await Task.sleep(for: .milliseconds(200))
        }
        print("snapshot \(name): timed out waiting for screenshot")
    }
    #endif

    #if os(macOS)
    /// CGWindowListCreateImage is gone from the macOS 26 headers but still exported;
    /// capturing our own windows through it needs no Screen Recording permission.
    private typealias WindowListImage = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
    private func captureViaCoreGraphics(windows: [NSWindow], named name: String, into directory: String) -> Bool {
        guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { print("no CGWindowListCreateImage symbol"); return false }
        let fn = unsafeBitCast(sym, to: WindowListImage.self)
        guard let base = windows.first(where: { $0.sheetParent == nil }) ?? windows.first else { return false }
        // kCGWindowListOptionIncludingWindow = 1 << 3, kCGWindowImageBoundsIgnoreFraming = 1 << 0, kCGWindowImageBestResolution = 1 << 3
        func save(_ window: NSWindow, suffix: String) -> Bool {
            guard let img = fn(.null, 1 << 3, UInt32(window.windowNumber), (1 << 0) | (1 << 3))?.takeRetainedValue(), img.width > 1 else { print("CG capture returned nothing"); return false }
            let rep = NSBitmapImageRep(cgImage: img)
            guard let png = rep.representation(using: .png, properties: [:]) else { return false }
            try? png.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name + suffix + ".png"))
            print("snapshot \(name)\(suffix) via CG: \(img.width)x\(img.height)")
            return true
        }
        let ok = save(base, suffix: "")
        for sheet in windows where sheet.sheetParent != nil { _ = save(sheet, suffix: "-sheet") }
        return ok
    }

    /// Renders every visible window (main + any sheet) from inside the process,
    /// so no Screen Recording permission is needed. Backdrop blur is approximated.
    private func capture(named name: String, into directory: String) {
        let windows = NSApp.windows.filter { $0.isVisible && $0.contentView != nil }
        if captureViaCoreGraphics(windows: windows, named: name, into: directory) { return }
        guard let base = windows.first(where: { $0.sheetParent == nil }) ?? windows.first else { print("snapshot \(name): no window"); return }
        let scale = base.backingScaleFactor
        let ordered = windows.sorted { ($0.sheetParent == nil ? 0 : 1) < ($1.sheetParent == nil ? 0 : 1) }
        let union = ordered.reduce(base.frame) { $0.union($1.frame) }
        let size = NSSize(width: union.width * scale, height: union.height * scale)
        guard let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
        for window in ordered {
            guard let view = window.contentView?.superview ?? window.contentView, let layer = view.layer,
                  let ctx = NSGraphicsContext.current?.cgContext else { continue }
            ctx.saveGState()
            ctx.translateBy(x: (window.frame.minX - union.minX) * scale, y: (window.frame.minY - union.minY) * scale)
            ctx.scaleBy(x: scale, y: scale)
            if view.isFlipped { ctx.translateBy(x: 0, y: view.bounds.height); ctx.scaleBy(x: 1, y: -1) }
            layer.render(in: ctx)
            ctx.restoreGState()
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let png = out.representation(using: .png, properties: [:]) else { return }
        let url = URL(fileURLWithPath: directory).appendingPathComponent(name + ".png")
        try? png.write(to: url)
        print("snapshot \(name): \(Int(size.width))x\(Int(size.height)) windows=\(ordered.count)")
    }
    #endif
}
#endif
