// LivePaper – Main Application Delegate

import AppKit

class LivePaperApp: NSObject, NSApplicationDelegate {
    var wallpaperWindows: [WallpaperWindow] = []
    var clockWindows: [ClockWindow] = []
    var clockViews: [MondClockView] = []
    var videoViews: [VideoWallpaperView] = []
    var isPaused = false
    var clockEnabled = true
    var currentVideoURL: URL

    var currentVideoName: String { currentVideoURL.lastPathComponent }

    var statusBar: StatusBarController?
    var cmdListener: CommandListener?
    var dashboard: DashboardController?
    var screensaverController: ScreensaverController?
    var persistence: WindowPersistenceManager?
    var batteryMonitor: BatteryMonitor?
    private var pausedForBattery = false
    private let aerialsInjector = AerialsInjector()
    private var activityToken: NSObjectProtocol?

    private var hasVideo: Bool

    init(videoURL: URL?) {
        if let u = videoURL {
            self.currentVideoURL = u
            self.hasVideo = true
        } else {
            self.currentVideoURL = URL(fileURLWithPath: "/dev/null")
            self.hasVideo = false
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerBundledFonts()
        // Menu-bar only — no Dock icon
        NSApp.setActivationPolicy(.accessory)
        setupEditMenu()

        dashboard = DashboardController(app: self)
        statusBar = StatusBarController(app: self)
        cmdListener = CommandListener(app: self)

        // Enable launch-at-login once if never configured (idempotent if already on)
        if UserDefaults.standard.object(forKey: "LP3.loginItemBootstrapped") == nil {
            _ = LoginItemManager.setEnabled(true)
            UserDefaults.standard.set(true, forKey: "LP3.loginItemBootstrapped")
        }

        if hasVideo {
            startWallpaper()
        }

        if LivePaperConfig.shared.followAppleAerials {
            startFollowingAppleAerials()
        }

        // Do not open dashboard on launch (menu-bar app)

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(displayWillSleep),
            name: NSWorkspace.screensDidSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(displayDidWake),
            name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    func startFollowingAppleAerials() {
        LivePaperConfig.shared.followAppleAerials = true
        AppleAerialsFollower.shared.start { [weak self] url in
            DispatchQueue.main.async {
                self?.applyFollowedVideo(url)
            }
        }
        statusBar?.rebuildMenu()
    }

    func refreshAppleAerials() {
        AppleAerialsFollower.shared.refreshNow()
    }

    private func applyFollowedVideo(_ url: URL) {
        guard LivePaperConfig.shared.followAppleAerials else { return }
        if url.path == currentVideoURL.path && hasVideo { return }
        changeVideo(url: url, fromFollow: true)
    }

    func startWallpaper() {
        setupWallpaper()
        clockEnabled = LivePaperConfig.shared.clockEnabled
        if clockEnabled { setupClock() }

        screensaverController = ScreensaverController(app: self)
        screensaverController?.start()

        persistence = WindowPersistenceManager(app: self)
        persistence?.start()

        batteryMonitor = BatteryMonitor(app: self)

        LivePaperConfig.shared.wallpaperVideoPath = currentVideoURL.path

        // Only inject when user explicitly enables lock-screen inject (off in Follow mode)
        if LivePaperConfig.shared.lockScreenEnabled && !LivePaperConfig.shared.followAppleAerials {
            injectToAerials()
        }
    }

    func injectToAerials(forceRestart: Bool = true) {
        let url = currentVideoURL
        guard url.path != "/dev/null" else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            if self.aerialsInjector.inject(videoURL: url, forceRestart: forceRestart) {
                NSLog("LivePaper: Injected video into Apple aerials for screensaver/lock screen")
            } else {
                NSLog("LivePaper: Aerials injection failed — lock screen may show default wallpaper")
            }
        }
    }

    func removeFromAerials() {
        aerialsInjector.remove()
    }

    private var lastScreenLayoutKey: String = ""

    private func screenLayoutKey() -> String {
        NSScreen.screens.map { s in
            let f = s.frame
            return String(format: "%.0f,%.0f,%.0f,%.0f@%.0f",
                          f.origin.x, f.origin.y, f.size.width, f.size.height,
                          s.backingScaleFactor)
        }.joined(separator: "|")
    }

    func setupWallpaper() {
        lastScreenLayoutKey = screenLayoutKey()
        for w in wallpaperWindows { w.close() }
        wallpaperWindows.removeAll(); videoViews.removeAll()
        for obs in occlusionObservers { NotificationCenter.default.removeObserver(obs) }
        occlusionObservers.removeAll()
        for screen in NSScreen.screens {
            let w = WallpaperWindow(screen: screen)
            let v = VideoWallpaperView(frame: screen.frame, videoURL: currentVideoURL,
                                       volume: LivePaperConfig.shared.volume)
            w.contentView = v; w.orderFront(nil)
            wallpaperWindows.append(w); videoViews.append(v)
            // No occlusion observers — pausing on cover/minimize caused flicker
        }
        NSLog("LivePaper: setupWallpaper — created %d windows for %d screens",
              wallpaperWindows.count, NSScreen.screens.count)
        // Re-apply battery mode to the freshly created views
        if pausedForBattery {
            for v in videoViews { v.pause() }
        } else if batteryMonitor?.isOnBattery == true {
            for v in videoViews { v.setBatteryMode(true) }
        }
    }

    func setupClock() {
        for w in clockWindows { w.close() }
        clockWindows.removeAll(); clockViews.removeAll()
        for screen in NSScreen.screens {
            let cw = ClockWindow(screen: screen)
            let cv = MondClockView(frame: cw.contentView!.bounds, style: LivePaperConfig.shared.clockStyle)
            cw.contentView = cv; cw.orderFront(nil)
            clockWindows.append(cw); clockViews.append(cv)
        }
    }

    func showClock() {
        clockEnabled = true; LivePaperConfig.shared.clockEnabled = true; setupClock()
    }
    func hideClock() {
        clockEnabled = false; LivePaperConfig.shared.clockEnabled = false
        for w in clockWindows { w.close() }; clockWindows.removeAll(); clockViews.removeAll()
    }
    func setClockStyle(_ s: Int) {
        LivePaperConfig.shared.clockStyle = s; for v in clockViews { v.setStyle(s) }
    }

    @objc func screensChanged() {
        guard hasVideo else { return }
        let key = screenLayoutKey()
        // Minimize/open apps often fires this notification WITHOUT real layout change.
        // Only rebuild players when screen count/geometry actually changes.
        if key == lastScreenLayoutKey {
            reorderWindows()
            return
        }
        NSLog("LivePaper: Real screen layout change — rebuilding wallpaper")
        lastScreenLayoutKey = key
        setupWallpaper()
        if clockEnabled { setupClock() }
        if screensaverController?.isActive == true {
            screensaverController?.handleScreenChange()
        }
    }
    @objc func spaceChanged() {
        // Soft reorder only — never pause/rebuild (that causes minimize flicker)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.reorderWindows() }
    }

    private var pausedForSleep = false
    private(set) var displaySleeping = false
    private var pausedForOcclusion = false
    private var occlusionObservers: [NSObjectProtocol] = []

    @objc func displayWillSleep() {
        displaySleeping = true
        if !isPaused {
            pausedForSleep = true
            for v in videoViews { v.pause() }
        }
    }

    @objc func displayDidWake() {
        displaySleeping = false
        NSLog("LivePaper: Display woke up — scheduling recovery")
        // Give the GPU a moment to come back after display sleep
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            if self.pausedForSleep {
                self.pausedForSleep = false
                if !self.isPaused && !(self.screensaverController?.isActive ?? false) {
                    for v in self.videoViews { v.resume() }
                }
            }
        }
    }

    func clearOcclusionPause() { pausedForOcclusion = false }

    private func handleOcclusionChange() {
        // Intentionally do NOT pause/resume on occlusion.
        // Pausing when an app covers the desktop, then resuming on minimize,
        // causes a black flicker. Keep the wallpaper playing underneath.
        // Screensaver/lock still manage their own pause via ScreensaverController.
        _ = screensaverController?.isActive
    }

    func changeVideo(url: URL, fromFollow: Bool = false) {
        // Manual library/file pick turns off Follow so we don't overwrite user choice
        if !fromFollow {
            LivePaperConfig.shared.followAppleAerials = false
            AppleAerialsFollower.shared.stop()
            statusBar?.rebuildMenu()
        }
        currentVideoURL = url
        LivePaperConfig.shared.wallpaperVideoPath = url.path
        if !hasVideo {
            hasVideo = true
            startWallpaper()
        } else {
            for v in videoViews { v.changeVideo(url: url) }
            if LivePaperConfig.shared.lockScreenEnabled && !LivePaperConfig.shared.followAppleAerials {
                injectToAerials()
            }
        }
        if isPaused { isPaused = false }
        statusBar?.updateNowPlaying()
        dashboard?.updateVideoLabel()
    }

    /// Re-load video on all players (equivalent to clicking the video in library again).
    /// Lighter than fullRebuild — reuses existing AVQueuePlayer objects.
    func reloadAllPlayers() {
        guard hasVideo else { return }
        let url = currentVideoURL
        for v in videoViews { v.changeVideo(url: url) }
    }

    /// Nuclear option: tears down and rebuilds every player from scratch.
    func rebuildAllPlayers() {
        guard hasVideo else { return }
        let url = currentVideoURL
        for v in videoViews { v.fullRebuild(url: url) }
    }

    func pause() {
        isPaused = true
        for v in videoViews { v.pause() }
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
    }
    func resume() {
        isPaused = false
        if pausedForBattery {
            for v in videoViews { v.pause() }
            return
        }
        for v in videoViews { v.resume() }
        if activityToken == nil {
            activityToken = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated, .idleSystemSleepDisabled],
                reason: "LivePaper video wallpaper playback")
        }
    }

    func enterBatteryMode() {
        if LivePaperConfig.shared.pauseOnBattery {
            pausedForBattery = true
            if !isPaused { for v in videoViews { v.pause() } }
            // Allow App Nap when paused on battery
            if let token = activityToken {
                ProcessInfo.processInfo.endActivity(token)
                activityToken = nil
            }
            NSLog("LivePaper: Battery mode — paused video")
        } else {
            for v in videoViews { v.setBatteryMode(true) }
            NSLog("LivePaper: Battery mode — reduced quality")
        }
    }
    func exitBatteryMode() {
        pausedForBattery = false
        for v in videoViews { v.setBatteryMode(false) }
        if !isPaused {
            for v in videoViews { v.resume() }
            // Prevent App Nap on AC while playing
            if activityToken == nil {
                activityToken = ProcessInfo.processInfo.beginActivity(
                    options: [.userInitiated, .idleSystemSleepDisabled],
                    reason: "LivePaper video wallpaper playback")
            }
        }
        NSLog("LivePaper: AC power — full quality")
    }
    func setVolume(_ vol: Float) {
        for v in videoViews { v.setVolume(vol) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppleAerialsFollower.shared.stop()
        batteryMonitor?.stop()
        screensaverController?.stop()
        persistence?.stop()
        for w in wallpaperWindows { w.close() }
        wallpaperWindows.removeAll()
        for w in clockWindows { w.close() }
        clockWindows.removeAll()
        videoViews.removeAll()
        clockViews.removeAll()
        cmdListener?.cleanup()
        for obs in occlusionObservers { NotificationCenter.default.removeObserver(obs) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        dashboard?.show()
        return true
    }

    /// Creates a standard Edit menu so Cmd+V/C/X/A work in text fields.
    private func setupEditMenu() {
        let mainMenu = NSApp.mainMenu ?? NSMenu()
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    private func reorderWindows() {
        if screensaverController?.isActive == true { return }
        let wp = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        let ck = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 2)
        for w in wallpaperWindows {
            if w.level != wp { w.level = wp }
            if !w.isVisible { w.orderFront(nil) }
        }
        for w in clockWindows {
            if w.level != ck { w.level = ck }
            if !w.isVisible { w.orderFront(nil) }
        }
    }
}
