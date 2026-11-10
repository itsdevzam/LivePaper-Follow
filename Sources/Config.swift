// LivePaper – Configuration & Font Registration

import AppKit
import CoreText

// MARK: - Font Registration

func registerBundledFonts() {
    if let resourcePath = Bundle.main.resourceURL {
        let fontURL = resourcePath.appendingPathComponent("Anurati-Regular.otf")
        if FileManager.default.fileExists(atPath: fontURL.path) {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        }
    }
    let userFont = NSString(string: "~/Library/Fonts/Anurati-Regular.otf").expandingTildeInPath
    if FileManager.default.fileExists(atPath: userFont) {
        CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: userFont) as CFURL, .process, nil)
    }
}

// MARK: - Configuration

class LivePaperConfig {
    static let shared = LivePaperConfig()
    private let d = UserDefaults.standard
    private let p = "LP3."

    var wallpaperVideoPath: String? {
        get { d.string(forKey: p + "wallpaperVideo") }
        set { d.set(newValue, forKey: p + "wallpaperVideo") }
    }
    var clockEnabled: Bool {
        get { d.object(forKey: p + "clockOn") as? Bool ?? false }
        set { d.set(newValue, forKey: p + "clockOn") }
    }
    var clockStyle: Int {
        get { d.integer(forKey: p + "clockStyle") }
        set { d.set(newValue, forKey: p + "clockStyle") }
    }
    var volume: Float {
        get {
            let key = p + "volume"
            if d.object(forKey: key) == nil { return 0.0 }
            return d.float(forKey: key)
        }
        set { d.set(newValue, forKey: p + "volume") }
    }
    var aerialsAssetID: String? {
        get { d.string(forKey: p + "aerialsAssetID") }
        set { d.set(newValue, forKey: p + "aerialsAssetID") }
    }
    /// Inject LivePaper video into Apple aerials (off by default — Follow mode leaves lock to Apple).
    var lockScreenEnabled: Bool {
        get { d.object(forKey: p + "lockScreenOn") as? Bool ?? false }
        set { d.set(newValue, forKey: p + "lockScreenOn") }
    }
    /// Mirror System Settings lock aerial pack + downloads on the desktop.
    var followAppleAerials: Bool {
        get { d.object(forKey: p + "followAppleAerials") as? Bool ?? true }
        set { d.set(newValue, forKey: p + "followAppleAerials") }
    }
    /// How to pick a clip inside the followed pack.
    /// - selected: play the exact video the user last picked/downloaded in Wallpaper Settings
    /// - timeOfDay: auto Morning/Day/Evening/Night from the clock
    enum FollowPlaybackMode: String {
        case selected
        case timeOfDay
    }
    var followPlaybackMode: FollowPlaybackMode {
        get {
            if let raw = d.string(forKey: p + "followPlaybackMode"),
               let mode = FollowPlaybackMode(rawValue: raw) {
                return mode
            }
            return .selected
        }
        set { d.set(newValue.rawValue, forKey: p + "followPlaybackMode") }
    }
    /// Also write Desktop + Lock Screen in System Settings to the chosen aerial.
    var applySystemWallpaper: Bool {
        get { d.object(forKey: p + "applySystemWallpaper") as? Bool ?? true }
        set { d.set(newValue, forKey: p + "applySystemWallpaper") }
    }
    /// Manual pick inside the pack (Selected mode). Nil = auto-detect from Settings/downloads.
    var manualAerialAssetID: String? {
        get { d.string(forKey: p + "manualAerialAssetID") }
        set { d.set(newValue, forKey: p + "manualAerialAssetID") }
    }
    var pauseOnBattery: Bool {
        get { d.object(forKey: p + "pauseOnBattery") as? Bool ?? false }
        set { d.set(newValue, forKey: p + "pauseOnBattery") }
    }
    /// Menu bar status icon. When off, app keeps running in background (reopen app to show Dashboard).
    var showMenuBarIcon: Bool {
        get { d.object(forKey: p + "showMenuBarIcon") as? Bool ?? true }
        set { d.set(newValue, forKey: p + "showMenuBarIcon") }
    }
}
