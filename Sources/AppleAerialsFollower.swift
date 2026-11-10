// LivePaper – Follow Apple Wallpaper Aerials
// Mirrors the pack you pick in System Settings → Wallpaper.
//
// Sources of truth (in order):
//  1. Desktop aerial assetID in Index.plist (if Desktop provider is aerials)
//  2. Newest downloaded pack in aerials/videos (Settings download/select often
//     updates files before Idle assetID — common when LivePaper covers desktop)
//  3. Idle (lock screen) aerial assetID
//
// Playback modes (user choice):
//  • selected  — exact clip last picked/downloaded in Wallpaper Settings
//  • timeOfDay — Morning/Day/Evening/Night from the clock

import AppKit
import Foundation

final class AppleAerialsFollower {
    static let shared = AppleAerialsFollower()

    private let storePath = NSString(string: "~/Library/Application Support/com.apple.wallpaper/Store/Index.plist").expandingTildeInPath
    private let videosDir = NSString(string: "~/Library/Application Support/com.apple.wallpaper/aerials/videos").expandingTildeInPath
    private let entriesPath = NSString(string: "~/Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json").expandingTildeInPath
    /// Bundled Tahoe catalog (includes Golden Gate Sunset etc. missing from older user cache).
    private let systemEntriesPath = "/System/Library/ExtensionKit/Extensions/WallpaperAerialsExtension.appex/Contents/Resources/entries.json"
    /// Apple ships Sunset as this aerial asset; until downloaded, Settings often falls back to the bundled mov.
    private let goldenGateSunsetID = "4207734D-74FE-4F92-B5E1-6EC8DEE24A15"
    private let systemGoldenGatePath = "/System/Library/Wallpapers/.default/Golden Gate.mov"
    private let goldenGateSubcategory = "67512508-D33E-4CBC-8A9E-BE55CEE35C4C"

    private var timer: Timer?
    private var lastResolvedPath: String?
    private var lastResolvedAssetID: String?
    private var lastSignature: String?
    private var onChange: ((URL) -> Void)?
    /// Sticky selection for "Selected video" mode until a newer download/touch appears.
    private var stickySelectedID: String?

    private enum DayPart: String {
        case morning, day, evening, night
    }

    private struct VideoInfo {
        let url: URL
        let id: String
        let mtime: Date
        let sourceName: String   // filename from SourceURL xattr
        let packKey: String
        let label: String
        let subcategories: [String]
        let preferredOrder: Int
    }

    struct PackChoice: Equatable {
        let id: String
        let title: String
        let url: URL
    }

    private init() {}

    // MARK: - Public

    func resolveCurrentVideo() -> URL? {
        resolveCurrent()?.url
    }

    /// Current pack clips for manual menu (includes Sunset stand-in when needed).
    func availablePackChoices() -> [PackChoice] {
        let videos = loadVideos()
        let desktopID = readAerialAssetID(section: "Desktop")
        let idleID = readAerialAssetID(section: "Idle")
        var pack = selectPack(from: videos, desktopID: desktopID, idleID: idleID)
        if pack.isEmpty { pack = videos }
        if isGoldenGatePack(pack), let sunset = sunsetVideoURL(),
           !pack.contains(where: { $0.id.caseInsensitiveCompare(goldenGateSunsetID) == .orderedSame }) {
            pack.append(VideoInfo(
                url: sunset, id: goldenGateSunsetID, mtime: Date.distantPast,
                sourceName: "GG_A_SUNSET", packKey: pack.first?.packKey ?? "GG_A",
                label: "Golden Gate Sunset", subcategories: [goldenGateSubcategory], preferredOrder: 0
            ))
        }
        return pack
            .map { PackChoice(id: $0.id, title: friendlyTitle(for: $0), url: $0.url) }
            .sorted { $0.title < $1.title }
    }

    /// User manually picked a clip — Selected mode + optional system apply.
    func selectManual(assetID: String) {
        LivePaperConfig.shared.followPlaybackMode = .selected
        LivePaperConfig.shared.manualAerialAssetID = assetID
        stickySelectedID = assetID
        tick(forceNotify: true)
    }

    func clearManualSelection() {
        LivePaperConfig.shared.manualAerialAssetID = nil
        stickySelectedID = nil
        tick(forceNotify: true)
    }

    private struct Resolved {
        let url: URL
        let assetID: String
    }

    private func resolveCurrent() -> Resolved? {
        let videos = loadVideos()
        guard !videos.isEmpty else {
            NSLog("LivePaper: Follow — no aerial videos downloaded")
            return nil
        }

        let desktopID = readAerialAssetID(section: "Desktop")
        let idleID = readAerialAssetID(section: "Idle")

        let packVideos = selectPack(from: videos, desktopID: desktopID, idleID: idleID)
        guard !packVideos.isEmpty else {
            guard let v = videos.max(by: { $0.mtime < $1.mtime }) else { return nil }
            return Resolved(url: v.url, assetID: v.id)
        }

        if packVideos.count == 1 {
            stickySelectedID = packVideos[0].id
            return Resolved(url: packVideos[0].url, assetID: packVideos[0].id)
        }

        switch LivePaperConfig.shared.followPlaybackMode {
        case .selected:
            return resolveSelected(packVideos, desktopID: desktopID, idleID: idleID)
        case .timeOfDay:
            return resolveTimeOfDay(packVideos, preferredID: desktopID ?? idleID)
        }
    }

    /// Exact user pick: manual menu > Desktop/Idle assetID > newest download.
    /// Golden Gate Sunset often has no downloaded .mov — use bundled Golden Gate.mov.
    private func resolveSelected(_ packVideos: [VideoInfo], desktopID: String?, idleID: String?) -> Resolved? {
        // 1) Manual menu pick
        if let manual = LivePaperConfig.shared.manualAerialAssetID {
            if manual.caseInsensitiveCompare(goldenGateSunsetID) == .orderedSame,
               let sunset = sunsetVideoURL() {
                stickySelectedID = goldenGateSunsetID
                return Resolved(url: sunset, assetID: goldenGateSunsetID)
            }
            if let exact = packVideos.first(where: { $0.id.caseInsensitiveCompare(manual) == .orderedSame }) {
                stickySelectedID = exact.id
                return Resolved(url: exact.url, assetID: exact.id)
            }
        }

        // 2) Explicit Index selection when it points inside this pack
        for pref in [desktopID, idleID].compactMap({ $0 }) {
            if pref.caseInsensitiveCompare(goldenGateSunsetID) == .orderedSame,
               let sunset = sunsetVideoURL() {
                stickySelectedID = goldenGateSunsetID
                NSLog("LivePaper: Follow[selected] — Golden Gate Sunset")
                return Resolved(url: sunset, assetID: goldenGateSunsetID)
            }
            if let exact = packVideos.first(where: { $0.id.caseInsensitiveCompare(pref) == .orderedSame }) {
                stickySelectedID = exact.id
                NSLog("LivePaper: Follow[selected] — Index asset %@", exact.id)
                return Resolved(url: exact.url, assetID: exact.id)
            }
        }

        // 3) Newest file in pack + Sunset via Desktop LastSet when default
        var candidates: [(id: String, date: Date, url: URL, label: String)] = packVideos.map {
            ($0.id, $0.mtime, $0.url, $0.sourceName.isEmpty ? $0.id : $0.sourceName)
        }

        if isGoldenGatePack(packVideos),
           let sunset = sunsetVideoURL(),
           let deskInfo = readDesktopProviderInfo(),
           deskInfo.provider == "default",
           let lastSet = deskInfo.lastSet {
            candidates.append((goldenGateSunsetID, lastSet, sunset, "Golden Gate Sunset (system)"))
        }

        guard let best = candidates.max(by: { $0.date < $1.date }) else { return nil }

        if let sticky = stickySelectedID,
           let kept = candidates.first(where: { $0.id.caseInsensitiveCompare(sticky) == .orderedSame }),
           best.date <= kept.date.addingTimeInterval(1) {
            return Resolved(url: kept.url, assetID: kept.id)
        }

        stickySelectedID = best.id
        NSLog("LivePaper: Follow[selected] — %@ (%@)", best.id, best.label)
        return Resolved(url: best.url, assetID: best.id)
    }

    private func resolveTimeOfDay(_ packVideos: [VideoInfo], preferredID: String?) -> Resolved? {
        var pool = packVideos
        if isGoldenGatePack(packVideos), let sunset = sunsetVideoURL(),
           !pool.contains(where: { $0.id.caseInsensitiveCompare(goldenGateSunsetID) == .orderedSame }) {
            pool.append(VideoInfo(
                url: sunset,
                id: goldenGateSunsetID,
                mtime: Date.distantPast,
                sourceName: "GG_A_SUNSET_Golden_Gate_Sunset.mov",
                packKey: packVideos.first?.packKey ?? "GG_A",
                label: "Golden Gate Sunset",
                subcategories: [goldenGateSubcategory],
                preferredOrder: 0
            ))
        }

        let part = currentDayPart()
        if let best = pickByDayPart(pool, part: part, preferredID: preferredID) {
            NSLog("LivePaper: Follow[time] — %@ → %@", part.rawValue, best.sourceName)
            return Resolved(url: best.url, assetID: best.id)
        }
        if let pref = preferredID,
           let exact = pool.first(where: { $0.id.caseInsensitiveCompare(pref) == .orderedSame }) {
            return Resolved(url: exact.url, assetID: exact.id)
        }
        guard let newest = packVideos.max(by: { $0.mtime < $1.mtime }) else { return nil }
        return Resolved(url: newest.url, assetID: newest.id)
    }

    private func friendlyTitle(for v: VideoInfo) -> String {
        let raw = (v.label + " " + v.sourceName).trimmingCharacters(in: .whitespaces)
        let u = raw.uppercased()
        if u.contains("SUNSET") { return "Golden Gate Sunset" }
        if u.contains("NIGHT") { return "Golden Gate Night" }
        if u.contains("EVENING") { return "Golden Gate Evening" }
        if u.contains("DAY") || u.contains("BLUFF") { return "Golden Gate Day" }
        if u.contains("MORNING") { return "Morning" }
        if !v.label.isEmpty { return v.label }
        if !v.sourceName.isEmpty { return String(v.sourceName.prefix(40)) }
        return String(v.id.prefix(8))
    }

    private func sunsetVideoURL() -> URL? {
        let aerial = (videosDir as NSString).appendingPathComponent("\(goldenGateSunsetID).mov")
        if FileManager.default.fileExists(atPath: aerial) {
            return URL(fileURLWithPath: aerial)
        }
        if FileManager.default.fileExists(atPath: systemGoldenGatePath) {
            return URL(fileURLWithPath: systemGoldenGatePath)
        }
        return nil
    }

    private func isGoldenGatePack(_ videos: [VideoInfo]) -> Bool {
        videos.contains {
            $0.packKey.uppercased().contains("GG_A")
                || $0.subcategories.contains(where: { $0.caseInsensitiveCompare(goldenGateSubcategory) == .orderedSame })
                || $0.sourceName.uppercased().contains("GG_A_")
        }
    }

    func start(onChange: @escaping (URL) -> Void) {
        self.onChange = onChange
        timer?.invalidate()
        // Fast enough to catch Settings changes; slight lag is OK
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer?.tolerance = 1.0
        tick(forceNotify: true)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        onChange = nil
        lastResolvedPath = nil
        lastResolvedAssetID = nil
        lastSignature = nil
    }

    func refreshNow() {
        tick(forceNotify: true)
    }

    // MARK: - Poll

    private func tick(forceNotify: Bool = false) {
        guard LivePaperConfig.shared.followAppleAerials else { return }
        let sig = folderSignature()
        if !forceNotify, sig == lastSignature, lastResolvedPath != nil {
            // Still re-check day-part on the hour boundary via resolve
        }
        lastSignature = sig

        guard let resolved = resolveCurrent() else { return }
        let url = resolved.url
        let assetChanged = resolved.assetID != lastResolvedAssetID
        let pathChanged = url.path != lastResolvedPath

        // Only touch System Wallpaper when the aerial ID actually changes.
        // Restarting WallpaperAgent on every poll causes delayed desktop flicker.
        if LivePaperConfig.shared.applySystemWallpaper, assetChanged || (forceNotify && lastResolvedAssetID == nil) {
            let id = resolved.assetID
            let ensureURL = url
            DispatchQueue.global(qos: .utility).async {
                SystemAerialSetter.shared.apply(
                    assetID: id,
                    ensureVideoAt: ensureURL,
                    forceRestart: true
                )
            }
        }

        if forceNotify || pathChanged {
            lastResolvedPath = url.path
            lastResolvedAssetID = resolved.assetID
            NSLog("LivePaper: Follow — using %@ (%@)", url.lastPathComponent, resolved.assetID)
            onChange?(url)
        } else if assetChanged {
            lastResolvedAssetID = resolved.assetID
        }
    }

    private func folderSignature() -> String {
        let fm = FileManager.default
        var parts: [String] = []
        if let attrs = try? fm.attributesOfItem(atPath: storePath),
           let m = attrs[.modificationDate] as? Date {
            parts.append("idx:\(m.timeIntervalSince1970)")
        }
        if let desk = readDesktopProviderInfo() {
            parts.append("desk:\(desk.provider):\(desk.lastSet?.timeIntervalSince1970 ?? 0)")
        }
        if let items = try? fm.contentsOfDirectory(atPath: videosDir) {
            for name in items.sorted() where name.lowercased().hasSuffix(".mov") || name.lowercased().hasSuffix(".mp4") {
                let path = (videosDir as NSString).appendingPathComponent(name)
                if let attrs = try? fm.attributesOfItem(atPath: path),
                   let m = attrs[.modificationDate] as? Date,
                   let s = attrs[.size] as? NSNumber {
                    parts.append("\(name):\(m.timeIntervalSince1970):\(s)")
                }
            }
        }
        let hour = Calendar.current.component(.hour, from: Date())
        parts.append("h:\(hour)")
        return parts.joined(separator: "|")
    }

    // MARK: - Index.plist

    private func readAerialAssetID(section: String) -> String? {
        guard let plist = loadIndex() else { return nil }
        // Prefer per-display / per-space, then AllSpaces, then SystemDefault
        let roots: [[String: Any]] = {
            var list: [[String: Any]] = []
            if let displays = plist["Displays"] as? [String: Any] {
                for (_, v) in displays {
                    if let d = v as? [String: Any] { list.append(d) }
                }
            }
            if let spaces = plist["Spaces"] as? [String: Any] {
                for (_, spaceVal) in spaces {
                    guard let space = spaceVal as? [String: Any] else { continue }
                    if let def = space["Default"] as? [String: Any] { list.append(def) }
                    if let disp = space["Displays"] as? [String: Any] {
                        for (_, v) in disp {
                            if let d = v as? [String: Any] { list.append(d) }
                        }
                    }
                }
            }
            if let all = plist["AllSpacesAndDisplays"] as? [String: Any] { list.append(all) }
            if let sys = plist["SystemDefault"] as? [String: Any] { list.append(sys) }
            return list
        }()

        var newest: (Date, String)?
        for root in roots {
            guard let node = root[section] as? [String: Any],
                  let content = node["Content"] as? [String: Any],
                  let choices = content["Choices"] as? [[String: Any]]
            else { continue }

            for choice in choices {
                guard let provider = choice["Provider"] as? String,
                      provider == "com.apple.wallpaper.choice.aerials",
                      let cfgData = choice["Configuration"] as? Data,
                      let cfg = try? PropertyListSerialization.propertyList(from: cfgData, options: [], format: nil) as? [String: Any],
                      let assetID = cfg["assetID"] as? String, !assetID.isEmpty
                else { continue }

                let lastSet = (node["LastSet"] as? Date) ?? .distantPast
                if newest == nil || lastSet > newest!.0 {
                    newest = (lastSet, assetID)
                }
            }
        }
        return newest?.1
    }

    private func loadIndex() -> [String: Any]? {
        let url = URL(fileURLWithPath: storePath)
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return nil }
        return plist
    }

    private struct DesktopProviderInfo {
        let provider: String
        let lastSet: Date?
        let assetID: String?
    }

    /// Newest Desktop choice across displays/spaces (provider may be default / aerials / image).
    private func readDesktopProviderInfo() -> DesktopProviderInfo? {
        guard let plist = loadIndex() else { return nil }
        var best: DesktopProviderInfo?
        var bestDate = Date.distantPast

        func consider(_ node: [String: Any]) {
            guard let desk = node["Desktop"] as? [String: Any],
                  let content = desk["Content"] as? [String: Any],
                  let choices = content["Choices"] as? [[String: Any]],
                  let choice = choices.first,
                  let provider = choice["Provider"] as? String
            else { return }
            let lastSet = desk["LastSet"] as? Date
            var assetID: String? = nil
            if let cfgData = choice["Configuration"] as? Data, !cfgData.isEmpty,
               let cfg = try? PropertyListSerialization.propertyList(from: cfgData, options: [], format: nil) as? [String: Any] {
                assetID = cfg["assetID"] as? String
            }
            let date = lastSet ?? .distantPast
            if best == nil || date >= bestDate {
                bestDate = date
                best = DesktopProviderInfo(provider: provider, lastSet: lastSet, assetID: assetID)
            }
        }

        if let displays = plist["Displays"] as? [String: Any] {
            for (_, v) in displays { if let d = v as? [String: Any] { consider(d) } }
        }
        if let spaces = plist["Spaces"] as? [String: Any] {
            for (_, spaceVal) in spaces {
                guard let space = spaceVal as? [String: Any] else { continue }
                if let def = space["Default"] as? [String: Any] { consider(def) }
                if let disp = space["Displays"] as? [String: Any] {
                    for (_, v) in disp { if let d = v as? [String: Any] { consider(d) } }
                }
            }
        }
        if let all = plist["AllSpacesAndDisplays"] as? [String: Any] { consider(all) }
        if let sys = plist["SystemDefault"] as? [String: Any] { consider(sys) }
        return best
    }

    // MARK: - Videos / pack

    private func loadVideos() -> [VideoInfo] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: videosDir) else { return [] }
        let manifest = loadManifestByID()

        var result: [VideoInfo] = []
        for name in items {
            let ext = (name as NSString).pathExtension.lowercased()
            guard ext == "mov" || ext == "mp4" else { continue }
            let path = (videosDir as NSString).appendingPathComponent(name)
            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let size = attrs[.size] as? NSNumber, size.intValue > 100_000,
                  let mtime = attrs[.modificationDate] as? Date
            else { continue }

            let id = (name as NSString).deletingPathExtension
            let sourceName = sourceURLFileName(for: path)
            let meta = manifest[id.uppercased()]
            let pack = packKey(id: id, sourceName: sourceName, subcategories: meta?.subcategories ?? [])
            result.append(VideoInfo(
                url: URL(fileURLWithPath: path),
                id: id,
                mtime: mtime,
                sourceName: sourceName,
                packKey: pack,
                label: meta?.label ?? "",
                subcategories: meta?.subcategories ?? [],
                preferredOrder: meta?.preferredOrder ?? 999
            ))
        }
        return result
    }

    private func selectPack(from videos: [VideoInfo], desktopID: String?, idleID: String?) -> [VideoInfo] {
        func pack(for id: String?) -> String? {
            guard let id else { return nil }
            return videos.first(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame })?.packKey
        }

        let newest = videos.max(by: { $0.mtime < $1.mtime })
        let desktopPack = pack(for: desktopID)
        let idlePack = pack(for: idleID)
        let newestPack = newest?.packKey

        // 1) Desktop aerial selection wins when present
        if let desktopPack {
            let group = videos.filter { $0.packKey == desktopPack }
            if !group.isEmpty {
                NSLog("LivePaper: Follow — pack from Desktop (%@)", desktopPack)
                return group
            }
        }

        // 2) If newest downloads belong to a different pack than Idle, user switched in Settings
        if let newestPack, let idlePack, newestPack != idlePack {
            let group = videos.filter { $0.packKey == newestPack }
            if !group.isEmpty {
                NSLog("LivePaper: Follow — pack from newest download (%@), Idle was %@", newestPack, idlePack)
                return group
            }
        }
        if let newestPack, idlePack == nil, desktopPack == nil {
            let group = videos.filter { $0.packKey == newestPack }
            if !group.isEmpty {
                NSLog("LivePaper: Follow — pack from newest download (%@)", newestPack)
                return group
            }
        }
        // Newest pack even when Idle pack file is older (Idle Index stale)
        if let newest, let newestPack, let idleID,
           let idleVideo = videos.first(where: { $0.id.caseInsensitiveCompare(idleID) == .orderedSame }),
           newest.mtime > idleVideo.mtime.addingTimeInterval(30),
           newestPack != idlePack {
            let group = videos.filter { $0.packKey == newestPack }
            if !group.isEmpty {
                NSLog("LivePaper: Follow — newer pack %@ over stale Idle %@", newestPack, idlePack ?? "?")
                return group
            }
        }

        // 3) Idle lock-screen pack
        if let idlePack {
            let group = videos.filter { $0.packKey == idlePack }
            if !group.isEmpty {
                NSLog("LivePaper: Follow — pack from Idle (%@)", idlePack)
                return group
            }
        }

        // 4) Fallback: newest pack
        if let newestPack {
            return videos.filter { $0.packKey == newestPack }
        }
        return videos
    }

    private func packKey(id: String, sourceName: String, subcategories: [String]) -> String {
        if let sub = subcategories.first, !sub.isEmpty {
            return "sub:\(sub.uppercased())"
        }
        let name = sourceName.isEmpty ? id : sourceName
        // Golden Gate style: GG_A_DAY_..., GG_A_EVENING_...
        if let match = name.range(of: #"^GG_[A-Z]"#, options: .regularExpression) {
            return String(name[match]).uppercased()
        }
        if let match = name.range(of: #"^TA_[A-Z]"#, options: .regularExpression) {
            return String(name[match]).uppercased()
        }
        // Shot style W010_C003 / A018C0002 / S013_C001
        if let match = name.range(of: #"^[A-Z]\d{3}"#, options: .regularExpression) {
            return String(name[match]).uppercased()
        }
        if let match = name.range(of: #"^[A-Z]{1,3}\d+"#, options: .regularExpression) {
            return String(name[match]).uppercased()
        }
        return id.uppercased()
    }

    private func sourceURLFileName(for path: String) -> String {
        // xattr SourceURL set by WallpaperAerialsExtension on download
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        task.arguments = ["-p", "SourceURL", path]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return "" }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let url = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !url.isEmpty,
                  let last = url.split(separator: "/").last
            else { return "" }
            return last.removingPercentEncoding ?? String(last)
        } catch {
            return ""
        }
    }

    // MARK: - Manifest

    private struct ManifestAsset {
        let id: String
        let label: String
        let shotID: String
        let subcategories: [String]
        let preferredOrder: Int
    }

    private func loadManifestByID() -> [String: ManifestAsset] {
        var map: [String: ManifestAsset] = [:]
        // System catalog first (complete), then user cache overlays any newer local copy
        for path in [systemEntriesPath, entriesPath] {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let assets = root["assets"] as? [[String: Any]]
            else { continue }
            for a in assets {
                guard let id = a["id"] as? String else { continue }
                let asset = ManifestAsset(
                    id: id,
                    label: (a["accessibilityLabel"] as? String) ?? "",
                    shotID: (a["shotID"] as? String) ?? "",
                    subcategories: (a["subcategories"] as? [String]) ?? [],
                    preferredOrder: a["preferredOrder"] as? Int ?? 999
                )
                map[id.uppercased()] = asset
            }
        }
        return map
    }

    // MARK: - Time of day

    private func currentDayPart(date: Date = Date()) -> DayPart {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11:  return .morning
        case 11..<17: return .day
        case 17..<20: return .evening
        default:      return .night
        }
    }

    private func dayPartScore(_ text: String, part: DayPart) -> Int {
        let t = text.lowercased()
        switch part {
        case .morning:
            if t.contains("morning") || t.contains("sunrise") || t.contains("dawn") { return 100 }
            if t.contains("_day_") || t.contains(" day") { return 40 }
        case .day:
            if t.contains("afternoon") { return 100 }
            if t.contains("_day_") || (t.contains("day") && !t.contains("night")) { return 90 }
            if t.contains("cloud") { return 50 }
            if t.contains("morning") { return 30 }
        case .evening:
            if t.contains("evening") || t.contains("sunset") || t.contains("dusk") { return 100 }
            if t.contains("golden") { return 40 }
        case .night:
            if t.contains("night") || t.contains("midnight") { return 100 }
            if t.contains("evening") { return 30 }
        }
        return 0
    }

    private func pickByDayPart(_ videos: [VideoInfo], part: DayPart, preferredID: String?) -> VideoInfo? {
        var scored: [(Int, Int, VideoInfo)] = []
        for v in videos {
            let text = "\(v.label) \(v.sourceName) \(v.url.lastPathComponent)"
            let score = dayPartScore(text, part: part)
            scored.append((score, v.preferredOrder, v))
        }
        let matched = scored.filter { $0.0 > 0 }.sorted {
            if $0.0 != $1.0 { return $0.0 > $1.0 }
            return $0.1 < $1.1
        }
        return matched.first?.2
    }
}
