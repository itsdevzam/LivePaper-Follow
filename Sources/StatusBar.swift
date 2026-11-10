// LivePaper – Status Bar Controller

import AppKit

class StatusBarController {
    private var statusItem: NSStatusItem!
    private var app: LivePaperApp

    init(app: LivePaperApp) {
        self.app = app
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            // Original LivePaper menu icon (SF Symbol)
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            let img = NSImage(systemSymbolName: "play.rectangle.fill", accessibilityDescription: "LivePaper")
            img?.isTemplate = true
            btn.image = img?.withSymbolConfiguration(config) ?? img
            btn.imagePosition = .imageOnly
            btn.toolTip = "LivePaper"
        }
        rebuildMenu()
        applyVisibilityFromConfig()
    }

    /// Show/hide menu bar icon. App keeps running either way.
    func setMenuBarIconVisible(_ visible: Bool) {
        LivePaperConfig.shared.showMenuBarIcon = visible
        applyVisibilityFromConfig()
        if visible {
            rebuildMenu()
        }
    }

    func applyVisibilityFromConfig() {
        let visible = LivePaperConfig.shared.showMenuBarIcon
        statusItem.isVisible = visible
        // Ensure item still exists if system removed it while hidden
        if visible, statusItem.button == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let btn = statusItem.button {
                let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
                let img = NSImage(systemSymbolName: "play.rectangle.fill", accessibilityDescription: "LivePaper")
                img?.isTemplate = true
                btn.image = img?.withSymbolConfiguration(config) ?? img
                btn.imagePosition = .imageOnly
                btn.toolTip = "LivePaper"
            }
            rebuildMenu()
            statusItem.isVisible = true
        }
    }

    func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let cfg = LivePaperConfig.shared

        let modeTitle: String
        if cfg.followAppleAerials {
            let play = cfg.followPlaybackMode == .selected ? "Manual/Selected" : "Time of day"
            let sys = cfg.applySystemWallpaper ? " + System" : ""
            modeTitle = "Following: \(play)\(sys)"
        } else {
            modeTitle = "Custom video"
        }
        let modeItem = NSMenuItem(title: modeTitle, action: nil, keyEquivalent: "")
        modeItem.isEnabled = false
        menu.addItem(modeItem)

        let np = NSMenuItem(title: "Now Playing:", action: nil, keyEquivalent: ""); np.isEnabled = false
        menu.addItem(np)
        let vn = NSMenuItem(title: "  \(displayName(for: app.currentVideoURL))", action: nil, keyEquivalent: "")
        vn.isEnabled = false; vn.tag = 100
        menu.addItem(vn)
        menu.addItem(.separator())

        let follow = NSMenuItem(title: "Follow Apple Aerials", action: #selector(toggleFollow(_:)), keyEquivalent: "")
        follow.target = self
        follow.state = cfg.followAppleAerials ? .on : .off
        menu.addItem(follow)

        // Playback mode
        let modeMenu = NSMenu()
        let selected = NSMenuItem(title: "Selected / Manual", action: #selector(setModeSelected), keyEquivalent: "")
        selected.target = self
        selected.state = cfg.followPlaybackMode == .selected ? .on : .off
        selected.isEnabled = cfg.followAppleAerials
        modeMenu.addItem(selected)

        let timed = NSMenuItem(title: "Time of day (auto)", action: #selector(setModeTime), keyEquivalent: "")
        timed.target = self
        timed.state = cfg.followPlaybackMode == .timeOfDay ? .on : .off
        timed.isEnabled = cfg.followAppleAerials
        modeMenu.addItem(timed)

        let modeParent = NSMenuItem(title: "Follow Mode", action: nil, keyEquivalent: "")
        modeParent.isEnabled = cfg.followAppleAerials
        modeParent.submenu = modeMenu
        menu.addItem(modeParent)

        // Manual wallpaper picks from current pack
        let chooseMenu = NSMenu()
        let choices = AppleAerialsFollower.shared.availablePackChoices()
        if choices.isEmpty {
            let empty = NSMenuItem(title: "(No aerials downloaded)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            chooseMenu.addItem(empty)
        } else {
            for (idx, c) in choices.enumerated() {
                let item = NSMenuItem(title: c.title, action: #selector(choosePackVideo(_:)), keyEquivalent: "")
                item.target = self
                item.tag = idx
                item.representedObject = c.id
                let isOn = (cfg.manualAerialAssetID ?? "").caseInsensitiveCompare(c.id) == .orderedSame
                    && cfg.followPlaybackMode == .selected
                item.state = isOn ? .on : .off
                item.isEnabled = cfg.followAppleAerials
                chooseMenu.addItem(item)
            }
            chooseMenu.addItem(.separator())
            let clear = NSMenuItem(title: "Clear Manual Pick", action: #selector(clearManualPick), keyEquivalent: "")
            clear.target = self
            clear.isEnabled = cfg.followAppleAerials && cfg.manualAerialAssetID != nil
            chooseMenu.addItem(clear)
        }
        let chooseParent = NSMenuItem(title: "Choose Wallpaper…", action: nil, keyEquivalent: "")
        chooseParent.isEnabled = cfg.followAppleAerials
        chooseParent.submenu = chooseMenu
        menu.addItem(chooseParent)

        let applySys = NSMenuItem(title: "Also Set System Wallpaper", action: #selector(toggleApplySystem(_:)), keyEquivalent: "")
        applySys.target = self
        applySys.state = cfg.applySystemWallpaper ? .on : .off
        applySys.isEnabled = cfg.followAppleAerials
        menu.addItem(applySys)

        let refresh = NSMenuItem(title: "Refresh now…", action: #selector(refreshFollow), keyEquivalent: "r")
        refresh.target = self
        refresh.isEnabled = cfg.followAppleAerials
        menu.addItem(refresh)
        menu.addItem(.separator())

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        login.target = self
        login.state = LoginItemManager.isEnabled ? .on : .off
        menu.addItem(login)

        let hideMenu = NSMenuItem(title: "Hide Menu Bar Icon", action: #selector(hideMenuBarIcon), keyEquivalent: "")
        hideMenu.target = self
        menu.addItem(hideMenu)
        menu.addItem(.separator())

        let dash = NSMenuItem(title: "Open Dashboard...", action: #selector(openDash), keyEquivalent: ",")
        dash.target = self; menu.addItem(dash)
        menu.addItem(.separator())

        let pause = NSMenuItem(title: app.isPaused ? "Resume" : "Pause", action: #selector(togglePause(_:)), keyEquivalent: "p")
        pause.target = self; pause.tag = 200; menu.addItem(pause)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit LivePaper", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit)

        statusItem.menu = menu
    }

    private func displayName(for url: URL) -> String {
        if url.path == "/dev/null" { return "(none)" }
        if url.path.contains("Golden Gate.mov") { return "Golden Gate Sunset" }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        task.arguments = ["-p", "SourceURL", url.path]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run(); task.waitUntilExit()
            if task.terminationStatus == 0,
               let s = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               let last = s.split(separator: "/").last {
                let name = last.removingPercentEncoding ?? String(last)
                let u = name.uppercased()
                if u.contains("SUNSET") { return "Golden Gate Sunset" }
                if u.contains("NIGHT") { return "Golden Gate Night" }
                if u.contains("EVENING") { return "Golden Gate Evening" }
                if u.contains("DAY") { return "Golden Gate Day" }
                if name.hasPrefix("GG_A_") {
                    return name.replacingOccurrences(of: "GG_A_", with: "Golden Gate ")
                        .split(separator: "_").prefix(2).joined(separator: " ")
                }
                return String(name.prefix(40))
            }
        } catch {}
        return url.lastPathComponent
    }

    @objc func openDash() { app.dashboard?.show() }

    @objc func togglePause(_ s: NSMenuItem) {
        if app.isPaused { app.resume(); s.title = "Pause" } else { app.pause(); s.title = "Resume" }
    }

    @objc func quitApp() { NSApplication.shared.terminate(nil) }

    @objc func toggleFollow(_ s: NSMenuItem) {
        let on = s.state != .on
        LivePaperConfig.shared.followAppleAerials = on
        s.state = on ? .on : .off
        if on {
            app.startFollowingAppleAerials()
        } else {
            AppleAerialsFollower.shared.stop()
        }
        rebuildMenu()
        updateNowPlaying()
    }

    @objc func setModeSelected() {
        LivePaperConfig.shared.followPlaybackMode = .selected
        app.refreshAppleAerials()
        rebuildMenu()
        updateNowPlaying()
    }

    @objc func setModeTime() {
        LivePaperConfig.shared.followPlaybackMode = .timeOfDay
        LivePaperConfig.shared.manualAerialAssetID = nil
        app.refreshAppleAerials()
        rebuildMenu()
        updateNowPlaying()
    }

    @objc func choosePackVideo(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        AppleAerialsFollower.shared.selectManual(assetID: id)
        rebuildMenu()
        updateNowPlaying()
    }

    @objc func clearManualPick() {
        AppleAerialsFollower.shared.clearManualSelection()
        rebuildMenu()
        updateNowPlaying()
    }

    @objc func toggleApplySystem(_ s: NSMenuItem) {
        let on = s.state != .on
        LivePaperConfig.shared.applySystemWallpaper = on
        s.state = on ? .on : .off
        if on {
            SystemAerialSetter.shared.clearCache()
            app.refreshAppleAerials()
        }
        rebuildMenu()
    }

    @objc func refreshFollow() {
        app.refreshAppleAerials()
        updateNowPlaying()
    }

    @objc func toggleLogin(_ s: NSMenuItem) {
        let want = s.state != .on
        if LoginItemManager.setEnabled(want) {
            s.state = LoginItemManager.isEnabled ? .on : .off
        }
    }

    @objc func hideMenuBarIcon() {
        let alert = NSAlert()
        alert.messageText = "Hide Menu Bar Icon?"
        alert.informativeText = "LivePaper keeps running in the background. To show the icon again, open LivePaper (or click it in the Dock/Finder) and turn on “Show menu bar icon” in the Dashboard."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Hide Icon")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        setMenuBarIconVisible(false)
    }

    func updateNowPlaying() {
        if LivePaperConfig.shared.showMenuBarIcon {
            rebuildMenu()
        }
    }
}
