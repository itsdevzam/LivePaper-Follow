// LivePaper – Set native macOS Desktop + Lock aerial to an existing Apple asset.
// Uses Index.plist "linked" entries (same approach as AerialsInjector) so both
// Desktop and Lock Screen show the chosen clip in System Settings.

import AppKit
import Foundation

final class SystemAerialSetter {
    static let shared = SystemAerialSetter()

    private let storePath = NSString(string: "~/Library/Application Support/com.apple.wallpaper/Store/Index.plist").expandingTildeInPath
    private let videosDir = NSString(string: "~/Library/Application Support/com.apple.wallpaper/aerials/videos").expandingTildeInPath

    private var lastAppliedID: String?

    private init() {}

    @discardableResult
    func apply(assetID: String, ensureVideoAt sourceURL: URL? = nil, forceRestart: Bool = true) -> Bool {
        let id = assetID.uppercased()
        // Same clip already applied — never kill WallpaperAgent again (that flickers the desktop)
        if id == lastAppliedID {
            if let src = sourceURL { ensureVideoFile(assetID: id, source: src) }
            return true
        }

        if let src = sourceURL {
            ensureVideoFile(assetID: id, source: src)
        }

        guard writeIndex(assetID: id) else {
            NSLog("LivePaper: SystemAerialSetter — failed to write Index.plist")
            return false
        }

        lastAppliedID = id
        NSLog("LivePaper: SystemAerialSetter — Desktop+Lock → %@", id)

        if forceRestart {
            restartWallpaperAgent()
        }
        return true
    }

    func clearCache() {
        lastAppliedID = nil
    }

    // MARK: - Ensure video on disk

    private func ensureVideoFile(assetID: String, source: URL) {
        let fm = FileManager.default
        let destPath = (videosDir as NSString).appendingPathComponent("\(assetID).mov")
        if source.path == destPath, fm.fileExists(atPath: destPath) { return }

        try? fm.createDirectory(atPath: videosDir, withIntermediateDirectories: true)

        let srcSize = (try? fm.attributesOfItem(atPath: source.path)[.size] as? NSNumber)?.intValue ?? -1
        let dstSize = (try? fm.attributesOfItem(atPath: destPath)[.size] as? NSNumber)?.intValue ?? -2

        if srcSize > 0, srcSize != dstSize {
            do {
                if fm.fileExists(atPath: destPath) { try fm.removeItem(atPath: destPath) }
                try fm.copyItem(at: source, to: URL(fileURLWithPath: destPath))
                NSLog("LivePaper: SystemAerialSetter — copied %@ → %@", source.lastPathComponent, destPath)
            } catch {
                NSLog("LivePaper: SystemAerialSetter — copy failed: %@", error.localizedDescription)
            }
        }
    }

    // MARK: - Index.plist (linked override for Desktop + Idle)

    private func writeIndex(assetID: String) -> Bool {
        let configDict: [String: String] = ["assetID": assetID]
        guard let configData = try? PropertyListSerialization.data(
            fromPropertyList: configDict, format: .binary, options: 0
        ) else { return false }

        let storeURL = URL(fileURLWithPath: storePath)
        var store: [String: Any]
        if let data = try? Data(contentsOf: storeURL),
           let parsed = try? PropertyListSerialization.propertyList(
            from: data, options: .mutableContainersAndLeaves, format: nil
           ) as? [String: Any] {
            store = parsed
        } else {
            store = [:]
        }

        let now = Date()
        let choice: [String: Any] = [
            "Provider": "com.apple.wallpaper.choice.aerials",
            "Files": [] as [Any],
            "Configuration": configData
        ]
        let content: [String: Any] = [
            "Choices": [choice]
        ]
        let linked: [String: Any] = [
            "Content": content,
            "LastSet": now,
            "LastUse": now
        ]
        // "linked" = same aerial for Desktop and Lock everywhere
        let linkedEntry: [String: Any] = [
            "Type": "linked",
            "Linked": linked
        ]

        // Also keep an individual shape with both sections (some agents prefer this)
        let section: [String: Any] = [
            "Content": content,
            "LastSet": now,
            "LastUse": now
        ]
        let individualEntry: [String: Any] = [
            "Type": "individual",
            "Desktop": section,
            "Idle": section
        ]

        store["AllSpacesAndDisplays"] = linkedEntry
        store["SystemDefault"] = individualEntry

        if var displays = store["Displays"] as? [String: Any] {
            for key in displays.keys { displays[key] = individualEntry }
            store["Displays"] = displays
        }

        if var spaces = store["Spaces"] as? [String: Any] {
            for spaceKey in spaces.keys {
                var space = (spaces[spaceKey] as? [String: Any]) ?? [:]
                space["Default"] = individualEntry
                if var spaceDisplays = space["Displays"] as? [String: Any] {
                    for dKey in spaceDisplays.keys { spaceDisplays[dKey] = individualEntry }
                    space["Displays"] = spaceDisplays
                }
                spaces[spaceKey] = space
            }
            store["Spaces"] = spaces
        }

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: store, format: .binary, options: 0)
            let tmpURL = URL(fileURLWithPath: storePath + ".tmp")
            try data.write(to: tmpURL)
            _ = try FileManager.default.replaceItemAt(storeURL, withItemAt: tmpURL)
            return true
        } catch {
            NSLog("LivePaper: SystemAerialSetter write error: %@", error.localizedDescription)
            return false
        }
    }

    private func restartWallpaperAgent() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["WallpaperAgent"]
        try? task.run()
        task.waitUntilExit()
        NSLog("LivePaper: SystemAerialSetter — restarted WallpaperAgent")
    }
}
