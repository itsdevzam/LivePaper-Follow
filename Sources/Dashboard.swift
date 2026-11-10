// LivePaper – Dashboard (SwiftUI)
// Settings-first UI for Follow Apple Aerials + library + YouTube.

import SwiftUI
import AppKit

// MARK: - Theme (slate + amber — not purple)

private let accent = Color(red: 0.92, green: 0.62, blue: 0.28)      // warm amber
private let accentSoft = Color(red: 0.35, green: 0.62, blue: 0.68)  // soft teal
private let mutedGray = Color(white: 0.52)
private let cardBg = Color(red: 0.12, green: 0.13, blue: 0.15)
private let dashBg = Color(red: 0.07, green: 0.08, blue: 0.09)
private let stroke = Color.white.opacity(0.07)

// MARK: - State

class DashboardState: ObservableObject {
    @Published var videoName: String = "No video selected"
    @Published var thumbImage: NSImage? = nil
    @Published var isPaused: Bool = false
    @Published var volume: Double = 0
    @Published var clockEnabled: Bool = false
    @Published var clockStyle: Int = 0
    @Published var lockScreenEnabled: Bool = false
    @Published var followAppleAerials: Bool = true
    @Published var followPlaybackMode: String = LivePaperConfig.FollowPlaybackMode.selected.rawValue
    @Published var applySystemWallpaper: Bool = true
    @Published var manualAerialAssetID: String? = nil
    @Published var packChoices: [AppleAerialsFollower.PackChoice] = []
    @Published var launchAtLogin: Bool = false
    @Published var showMenuBarIcon: Bool = true
    @Published var pauseOnBattery: Bool = false
    @Published var libraryVideos: [URL] = []
    @Published var currentVideoPath: String = ""
    @Published var youtubeURL: String = ""
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0
    @Published var downloadStatus: String = ""
    @Published var isProcessing: Bool = false
    @Published var processStatus: String = ""

    weak var app: LivePaperApp?

    func refresh() {
        guard let app = app else { return }
        let path = app.currentVideoURL.path
        if path.contains("Golden Gate.mov") {
            videoName = "Golden Gate Sunset"
        } else {
            videoName = app.currentVideoName
        }
        isPaused = app.isPaused
        volume = Double(LivePaperConfig.shared.volume) * 100
        clockEnabled = app.clockEnabled
        clockStyle = LivePaperConfig.shared.clockStyle
        lockScreenEnabled = LivePaperConfig.shared.lockScreenEnabled
        followAppleAerials = LivePaperConfig.shared.followAppleAerials
        followPlaybackMode = LivePaperConfig.shared.followPlaybackMode.rawValue
        applySystemWallpaper = LivePaperConfig.shared.applySystemWallpaper
        manualAerialAssetID = LivePaperConfig.shared.manualAerialAssetID
        packChoices = AppleAerialsFollower.shared.availablePackChoices()
        launchAtLogin = LoginItemManager.isEnabled
        showMenuBarIcon = LivePaperConfig.shared.showMenuBarIcon
        pauseOnBattery = LivePaperConfig.shared.pauseOnBattery
        currentVideoPath = path
        libraryVideos = VideoLibrary.shared.videoFiles()
        if path != "/dev/null" {
            thumbImage = VideoLibrary.shared.thumbnail(for: app.currentVideoURL, size: CGSize(width: 320, height: 180))
        }
    }
}

// MARK: - Main View

struct DashboardView: View {
    @ObservedObject var state: DashboardState
    var actions: DashboardActions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                    .padding(.top, 10)

                Rectangle()
                    .fill(
                        LinearGradient(colors: [accent.opacity(0.85), accentSoft.opacity(0.55)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(height: 2)
                    .padding(.top, 14)
                    .padding(.bottom, 22)

                sectionLabel("NOW PLAYING")
                nowPlayingCard
                    .padding(.bottom, 22)

                sectionLabel("APPLE AERIALS")
                aerialsCard
                    .padding(.bottom, 22)

                sectionLabel("SETTINGS")
                settingsCard
                    .padding(.bottom, 22)

                sectionLabel("VIDEO LIBRARY")
                libraryGrid
                    .padding(.bottom, 14)

                actionButtons
                    .padding(.bottom, 22)

                sectionLabel("DOWNLOAD FROM YOUTUBE")
                youtubeSection
                    .padding(.bottom, 22)

                bottomBar
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(dashBg)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 14) {
            if let logo = NSImage(named: "AppIcon") ?? bundleLogo() {
                Image(nsImage: logo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("LivePaper")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("3.1")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accent.opacity(0.15))
                        .clipShape(Capsule())
                }
                Text("Follow Apple aerials on desktop · set system wallpaper")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(mutedGray)
            }
            Spacer()
        }
    }

    private func bundleLogo() -> NSImage? {
        if let url = Bundle.main.url(forResource: "livepaper-app-icon", withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return nil
    }

    // MARK: - Now Playing

    private var nowPlayingCard: some View {
        HStack(spacing: 18) {
            Group {
                if let img = state.thumbImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(white: 0.12))
                        .frame(width: 160, height: 90)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(state.videoName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .truncationMode(.middle)

                HStack(spacing: 10) {
                    Button(action: actions.play) {
                        Label("Play", systemImage: "play.fill")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .disabled(!state.isPaused)

                    Button(action: actions.pause) {
                        Label("Pause", systemImage: "pause.fill")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .disabled(state.isPaused)
                }

                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(mutedGray)
                    Slider(value: Binding(
                        get: { state.volume },
                        set: { actions.setVolume($0) }
                    ), in: 0...100)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(stroke, lineWidth: 1))
    }

    // MARK: - Apple Aerials (main settings users care about)

    private var aerialsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: Binding(
                get: { state.followAppleAerials },
                set: { actions.toggleFollowApple($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Follow Apple Aerials")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Desktop uses the pack you download in System Settings → Wallpaper")
                        .font(.system(size: 11))
                        .foregroundColor(mutedGray)
                }
            }
            .toggleStyle(.checkbox)

            if state.followAppleAerials {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Playback mode")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(mutedGray)
                    Picker("", selection: Binding(
                        get: { state.followPlaybackMode },
                        set: { actions.setFollowPlaybackMode($0) }
                    )) {
                        Text("Manual / Selected").tag(LivePaperConfig.FollowPlaybackMode.selected.rawValue)
                        Text("Time of day (auto)").tag(LivePaperConfig.FollowPlaybackMode.timeOfDay.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Toggle(isOn: Binding(
                    get: { state.applySystemWallpaper },
                    set: { actions.toggleApplySystemWallpaper($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Also set System Wallpaper")
                            .font(.system(size: 14, weight: .medium))
                        Text("Writes Desktop + Lock Screen to the same aerial")
                            .font(.system(size: 11))
                            .foregroundColor(mutedGray)
                    }
                }
                .toggleStyle(.checkbox)

                if !state.packChoices.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose wallpaper in this pack")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(mutedGray)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(state.packChoices, id: \.id) { choice in
                                let selected = (state.manualAerialAssetID ?? "").caseInsensitiveCompare(choice.id) == .orderedSame
                                    && state.followPlaybackMode == LivePaperConfig.FollowPlaybackMode.selected.rawValue
                                Button {
                                    actions.selectPackAerial(choice.id)
                                } label: {
                                    HStack {
                                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selected ? accent : mutedGray)
                                        Text(choice.title)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(selected ? accent.opacity(0.14) : Color.white.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(selected ? accent.opacity(0.45) : stroke, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(stroke, lineWidth: 1))
    }

    // MARK: - Settings

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: Binding(
                get: { state.launchAtLogin },
                set: { actions.toggleLaunchAtLogin($0) }
            )) {
                Text("Launch at Login")
                    .font(.system(size: 14))
            }
            .toggleStyle(.checkbox)

            Toggle(isOn: Binding(
                get: { state.showMenuBarIcon },
                set: { actions.toggleShowMenuBarIcon($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show menu bar icon")
                        .font(.system(size: 14))
                    Text("Off = hide icon, LivePaper still runs. Reopen the app to show Dashboard again.")
                        .font(.system(size: 11))
                        .foregroundColor(mutedGray)
                }
            }
            .toggleStyle(.checkbox)

            Toggle(isOn: Binding(
                get: { state.pauseOnBattery },
                set: { actions.togglePauseOnBattery($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pause video on battery")
                        .font(.system(size: 14))
                    Text("Off = lower quality on battery · On = pause completely")
                        .font(.system(size: 11))
                        .foregroundColor(mutedGray)
                }
            }
            .toggleStyle(.checkbox)

            Toggle(isOn: Binding(
                get: { state.lockScreenEnabled },
                set: { actions.toggleLockScreen($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inject custom library video into Lock Screen")
                        .font(.system(size: 14))
                    Text("Off while Following Apple (recommended)")
                        .font(.system(size: 11))
                        .foregroundColor(mutedGray)
                }
            }
            .toggleStyle(.checkbox)
            .disabled(state.followAppleAerials)

            HStack {
                Toggle(isOn: Binding(
                    get: { state.clockEnabled },
                    set: { actions.toggleClock($0) }
                )) {
                    Text("Show Mond clock on desktop")
                        .font(.system(size: 14))
                }
                .toggleStyle(.checkbox)
                Spacer()
                Picker("", selection: Binding(
                    get: { state.clockStyle },
                    set: { actions.setClockStyle($0) }
                )) {
                    Text("Classic").tag(0)
                    Text("Classic + Seconds").tag(1)
                    Text("Small").tag(2)
                }
                .labelsHidden()
                .frame(width: 160)
                .disabled(!state.clockEnabled)
            }
        }
        .padding(18)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(stroke, lineWidth: 1))
    }

    // MARK: - Library

    private var libraryGrid: some View {
        Group {
            if state.libraryVideos.isEmpty {
                Text("No library videos yet — add a file or download from YouTube")
                    .font(.system(size: 13))
                    .foregroundColor(mutedGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(state.libraryVideos.enumerated()), id: \.offset) { index, url in
                        videoThumbnail(url: url, index: index)
                    }
                }
                .padding(12)
                .background(cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(stroke, lineWidth: 1))
            }
        }
    }

    private func videoThumbnail(url: URL, index: Int) -> some View {
        let isActive = url.path == state.currentVideoPath
        return ZStack(alignment: .topTrailing) {
            Button(action: { actions.selectVideo(index) }) {
                VStack(spacing: 6) {
                    Group {
                        if let thumb = VideoLibrary.shared.thumbnail(for: url) {
                            Image(nsImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 80)
                                .clipped()
                        } else {
                            Rectangle().fill(Color(white: 0.12)).frame(height: 80)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isActive ? accent : Color.clear, lineWidth: 2)
                    )
                    Text(url.deletingPathExtension().lastPathComponent)
                        .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? accent : Color(white: 0.55))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .buttonStyle(.plain)

            Button(action: { actions.removeVideo(index) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(white: 0.7))
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button(action: actions.chooseFile) {
                Label("Choose Video File…", systemImage: "folder.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(accent.opacity(0.14))
                    .foregroundColor(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(state.isProcessing)

            Button(action: actions.browseMoewalls) {
                Label("Browse moewalls", systemImage: "globe")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(accentSoft.opacity(0.12))
                    .foregroundColor(accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - YouTube

    private var youtubeSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.22))

                TextField("Paste YouTube URL here…", text: Binding(
                    get: { state.youtubeURL },
                    set: { state.youtubeURL = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

                Button(action: { actions.downloadYouTube(state.youtubeURL) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Download")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .background(accent)
                    .foregroundColor(Color(white: 0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(state.isDownloading || state.isProcessing || state.youtubeURL.isEmpty)
            }

            if state.isDownloading || !state.downloadStatus.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: state.downloadProgress)
                        .progressViewStyle(.linear)
                        .tint(accent)
                    Text(state.downloadStatus)
                        .font(.system(size: 12))
                        .foregroundColor(mutedGray)
                }
            }
            if state.isProcessing {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: state.downloadProgress)
                        .progressViewStyle(.linear)
                        .tint(accentSoft)
                    Text(state.processStatus)
                        .font(.system(size: 12))
                        .foregroundColor(mutedGray)
                }
            }

            Text("Paste any YouTube URL — downloaded and converted for LivePaper.")
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.35))
        }
        .padding(16)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(stroke, lineWidth: 1))
    }

    private var bottomBar: some View {
        HStack {
            Button("Quit LivePaper") { actions.quit() }
                .foregroundColor(Color(white: 0.65))
            Spacer()
            Text("Menu bar app · Dock hidden")
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.28))
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .tracking(0.6)
            .foregroundColor(mutedGray)
            .padding(.bottom, 10)
    }
}

// MARK: - Actions

struct DashboardActions {
    var play: () -> Void = {}
    var pause: () -> Void = {}
    var setVolume: (Double) -> Void = { _ in }
    var chooseFile: () -> Void = {}
    var browseMoewalls: () -> Void = {}
    var selectVideo: (Int) -> Void = { _ in }
    var removeVideo: (Int) -> Void = { _ in }
    var downloadYouTube: (String) -> Void = { _ in }
    var toggleClock: (Bool) -> Void = { _ in }
    var setClockStyle: (Int) -> Void = { _ in }
    var toggleLockScreen: (Bool) -> Void = { _ in }
    var toggleFollowApple: (Bool) -> Void = { _ in }
    var setFollowPlaybackMode: (String) -> Void = { _ in }
    var toggleApplySystemWallpaper: (Bool) -> Void = { _ in }
    var selectPackAerial: (String) -> Void = { _ in }
    var toggleLaunchAtLogin: (Bool) -> Void = { _ in }
    var toggleShowMenuBarIcon: (Bool) -> Void = { _ in }
    var togglePauseOnBattery: (Bool) -> Void = { _ in }
    var quit: () -> Void = {}
}

// MARK: - Controller

class DashboardController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private weak var app: LivePaperApp?
    private var state = DashboardState()

    init(app: LivePaperApp) {
        self.app = app
        super.init()
        state.app = app
    }

    func show() {
        NSApp.setActivationPolicy(.regular)
        state.refresh()
        if let w = window {
            if w.isMiniaturized { w.deminiaturize(nil) }
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        buildWindow()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func updateVideoLabel() {
        state.refresh()
    }

    private func buildWindow() {
        let W: CGFloat = 740, H: CGFloat = 900
        let sf = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 800, height: 600)

        window = NSWindow(
            contentRect: NSRect(x: sf.midX - W/2, y: sf.midY - H/2, width: W, height: H),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window!.title = "LivePaper"
        window!.isReleasedWhenClosed = false
        window!.level = .normal
        window!.appearance = NSAppearance(named: .darkAqua)
        window!.delegate = self
        window!.titlebarAppearsTransparent = true
        window!.titleVisibility = .hidden
        window!.isMovableByWindowBackground = true
        window!.backgroundColor = NSColor(red: 0.07, green: 0.08, blue: 0.09, alpha: 1.0)
        window!.minSize = NSSize(width: 640, height: 700)

        let actions = DashboardActions(
            play:              { [weak self] in self?.app?.resume(); self?.state.isPaused = false },
            pause:             { [weak self] in self?.app?.pause(); self?.state.isPaused = true },
            setVolume:         { [weak self] v in
                let vol = Float(v) / 100.0
                LivePaperConfig.shared.volume = vol
                self?.app?.setVolume(vol)
                self?.state.volume = v
            },
            chooseFile:        { [weak self] in self?.chooseWallpaper() },
            browseMoewalls:    {
                if let url = URL(string: "https://moewalls.com/") {
                    NSWorkspace.shared.open(url)
                }
            },
            selectVideo:       { [weak self] idx in self?.selectLibraryVideo(idx) },
            removeVideo:       { [weak self] idx in self?.removeLibraryVideo(idx) },
            downloadYouTube:   { [weak self] url in self?.downloadFromYouTube(url) },
            toggleClock:       { [weak self] on in
                LivePaperConfig.shared.clockEnabled = on
                self?.state.clockEnabled = on
                if on { self?.app?.showClock() } else { self?.app?.hideClock() }
            },
            setClockStyle:     { [weak self] s in
                LivePaperConfig.shared.clockStyle = s
                self?.state.clockStyle = s
                self?.app?.setClockStyle(s)
            },
            toggleLockScreen:  { [weak self] on in
                if on && LivePaperConfig.shared.followAppleAerials {
                    self?.state.lockScreenEnabled = false
                    return
                }
                LivePaperConfig.shared.lockScreenEnabled = on
                self?.state.lockScreenEnabled = on
                if on { self?.app?.injectToAerials() } else { self?.app?.removeFromAerials() }
            },
            toggleFollowApple: { [weak self] on in
                LivePaperConfig.shared.followAppleAerials = on
                self?.state.followAppleAerials = on
                if on {
                    LivePaperConfig.shared.lockScreenEnabled = false
                    self?.state.lockScreenEnabled = false
                    self?.app?.removeFromAerials()
                    self?.app?.startFollowingAppleAerials()
                } else {
                    AppleAerialsFollower.shared.stop()
                    self?.app?.statusBar?.rebuildMenu()
                }
                self?.state.refresh()
            },
            setFollowPlaybackMode: { [weak self] raw in
                let mode = LivePaperConfig.FollowPlaybackMode(rawValue: raw) ?? .selected
                LivePaperConfig.shared.followPlaybackMode = mode
                if mode == .timeOfDay {
                    LivePaperConfig.shared.manualAerialAssetID = nil
                }
                self?.state.followPlaybackMode = mode.rawValue
                self?.app?.refreshAppleAerials()
                self?.app?.statusBar?.rebuildMenu()
                self?.state.refresh()
            },
            toggleApplySystemWallpaper: { [weak self] on in
                LivePaperConfig.shared.applySystemWallpaper = on
                self?.state.applySystemWallpaper = on
                if on {
                    SystemAerialSetter.shared.clearCache()
                    self?.app?.refreshAppleAerials()
                }
                self?.app?.statusBar?.rebuildMenu()
            },
            selectPackAerial: { [weak self] id in
                AppleAerialsFollower.shared.selectManual(assetID: id)
                self?.app?.statusBar?.rebuildMenu()
                self?.state.refresh()
            },
            toggleLaunchAtLogin: { [weak self] on in
                _ = LoginItemManager.setEnabled(on)
                self?.state.launchAtLogin = LoginItemManager.isEnabled
            },
            toggleShowMenuBarIcon: { [weak self] on in
                self?.app?.statusBar?.setMenuBarIconVisible(on)
                self?.state.showMenuBarIcon = LivePaperConfig.shared.showMenuBarIcon
            },
            togglePauseOnBattery: { [weak self] on in
                LivePaperConfig.shared.pauseOnBattery = on
                self?.state.pauseOnBattery = on
                if self?.app?.batteryMonitor?.isOnBattery == true {
                    if on { self?.app?.enterBatteryMode() }
                    else { self?.app?.exitBatteryMode(); self?.app?.enterBatteryMode() }
                }
            },
            quit: { NSApplication.shared.terminate(nil) }
        )

        let dashView = DashboardView(state: state, actions: actions)
        let hostingView = NSHostingView(rootView: dashView)
        hostingView.frame = NSRect(x: 0, y: 0, width: W, height: H)
        hostingView.autoresizingMask = [.width, .height]
        window!.contentView = hostingView
    }

    // MARK: - Library / YouTube (unchanged behavior)

    private func chooseWallpaper() {
        guard let url = pickVideo(title: "Choose Wallpaper Video") else { return }
        processAndImportVideo(sourceURL: url)
    }

    private static func probeVideoCodec(path: String) -> String {
        guard let ffprobe = findExecutable("ffprobe") else { return "" }
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: ffprobe)
        task.arguments = ["-v", "quiet", "-select_streams", "v:0",
                          "-show_entries", "stream=codec_name",
                          "-of", "csv=p=0", path]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        guard let _ = try? task.run() else { return "" }
        task.waitUntilExit()
        guard let data = pipe.fileHandleForReading.readDataToEndOfFile() as Data?,
              let out = String(data: data, encoding: .utf8) else { return "" }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n").first ?? ""
    }

    private static func probeVideoDuration(path: String) -> Double {
        guard let ffprobe = findExecutable("ffprobe") else { return 0 }
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: ffprobe)
        task.arguments = ["-v", "quiet", "-show_entries", "format=duration",
                          "-of", "csv=p=0", path]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        guard let _ = try? task.run() else { return 0 }
        task.waitUntilExit()
        guard let data = pipe.fileHandleForReading.readDataToEndOfFile() as Data?,
              let out = String(data: data, encoding: .utf8) else { return 0 }
        return Double(out.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private static func parseFFmpegTime(_ text: String) -> Double? {
        guard let range = text.range(of: "time=", options: .backwards) else { return nil }
        let after = String(text[range.upperBound...])
        let timeStr = after.components(separatedBy: " ").first ?? ""
        let parts = timeStr.components(separatedBy: ":")
        if parts.count == 3 {
            let h = Double(parts[0]) ?? 0
            let m = Double(parts[1]) ?? 0
            let s = Double(parts[2]) ?? 0
            return h * 3600 + m * 60 + s
        } else if let s = Double(parts[0]) {
            return s
        }
        return nil
    }

    private func processAndImportVideo(sourceURL: URL) {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let safeName = baseName.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let destName = safeName + ".mov"
        let destPath = (VideoLibrary.shared.libraryPath as NSString).appendingPathComponent(destName)

        guard let ffmpeg = Self.findExecutable("ffmpeg") else {
            if !FileManager.default.fileExists(atPath: destPath) {
                try? FileManager.default.copyItem(at: sourceURL, to: URL(fileURLWithPath: destPath))
            }
            let finalURL = URL(fileURLWithPath: destPath)
            app?.changeVideo(url: finalURL)
            state.isDownloading = false
            state.downloadStatus = ""
            state.refresh()
            return
        }

        state.isDownloading = false
        state.isProcessing = true
        state.downloadProgress = 0
        state.processStatus = "Analyzing video…"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let tmpPath = destPath + ".tmp.mov"
            let fm = FileManager.default
            try? fm.removeItem(atPath: tmpPath)

            let sourceCodec = Self.probeVideoCodec(path: sourceURL.path)
            let totalDuration = Self.probeVideoDuration(path: sourceURL.path)

            var args: [String]
            if sourceCodec == "hevc" {
                DispatchQueue.main.async { self?.state.processStatus = "Processing video for LivePaper…" }
                args = ["-i", sourceURL.path, "-c", "copy", "-movflags", "+faststart", "-y", tmpPath]
            } else {
                DispatchQueue.main.async { self?.state.processStatus = "Processing video for LivePaper…" }
                args = ["-i", sourceURL.path,
                        "-c:v", "hevc_videotoolbox", "-b:v", "20M", "-tag:v", "hvc1",
                        "-pix_fmt", "p010le", "-c:a", "aac", "-b:a", "192k",
                        "-movflags", "+faststart", "-y", tmpPath]
            }

            let task = Process()
            task.executableURL = URL(fileURLWithPath: ffmpeg)
            task.arguments = args
            task.standardOutput = FileHandle.nullDevice
            let errPipe = Pipe()
            task.standardError = errPipe
            var stderrBuf = ""
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
                stderrBuf += chunk
                if totalDuration > 0, let currentTime = Self.parseFFmpegTime(stderrBuf) {
                    let pct = min(currentTime / totalDuration, 0.99)
                    DispatchQueue.main.async {
                        self?.state.downloadProgress = pct
                        self?.state.processStatus = "Processing video for LivePaper… \(Int(pct * 100))%"
                    }
                    if stderrBuf.count > 500 { stderrBuf = String(stderrBuf.suffix(300)) }
                }
            }

            var success = false
            do {
                try task.run(); task.waitUntilExit()
                errPipe.fileHandleForReading.readabilityHandler = nil
                success = task.terminationStatus == 0
            } catch {
                errPipe.fileHandleForReading.readabilityHandler = nil
            }

            if success {
                let size = (try? fm.attributesOfItem(atPath: tmpPath)[.size] as? Int) ?? 0
                if size < 10000 { success = false }
            }

            if success {
                let srcInLibrary = sourceURL.path.hasPrefix(VideoLibrary.shared.libraryPath)
                if srcInLibrary && sourceURL.path != destPath { try? fm.removeItem(at: sourceURL) }
                if fm.fileExists(atPath: destPath) { try? fm.removeItem(atPath: destPath) }
                try? fm.moveItem(atPath: tmpPath, toPath: destPath)
            } else {
                try? fm.removeItem(atPath: tmpPath)
                if !fm.fileExists(atPath: destPath) {
                    try? fm.copyItem(at: sourceURL, to: URL(fileURLWithPath: destPath))
                }
            }

            let finalURL = URL(fileURLWithPath: destPath)
            DispatchQueue.main.async {
                self?.state.isProcessing = false
                self?.state.downloadProgress = 0
                self?.state.processStatus = ""
                VideoLibrary.shared.invalidateThumbnail(for: finalURL)
                self?.app?.changeVideo(url: finalURL)
                self?.state.refresh()
            }
        }
    }

    private func selectLibraryVideo(_ index: Int) {
        let videos = state.libraryVideos
        guard index >= 0, index < videos.count else { return }
        let url = videos[index]
        let codec = Self.probeVideoCodec(path: url.path)
        if codec != "hevc" && codec != "" {
            processAndImportVideo(sourceURL: url)
        } else {
            app?.changeVideo(url: url)
            state.refresh()
        }
    }

    private func removeLibraryVideo(_ index: Int) {
        let videos = state.libraryVideos
        guard index >= 0, index < videos.count else { return }
        let url = videos[index]
        if url.path == app?.currentVideoURL.path {
            let others = videos.filter { $0.path != url.path }
            if let next = others.randomElement() {
                app?.changeVideo(url: next)
                LivePaperConfig.shared.wallpaperVideoPath = next.path
            } else { return }
        }
        _ = VideoLibrary.shared.removeVideo(at: url)
        state.refresh()
    }

    private func downloadFromYouTube(_ urlString: String) {
        guard !urlString.isEmpty else { return }
        guard urlString.contains("youtube.com") || urlString.contains("youtu.be") else {
            state.isDownloading = true
            state.downloadStatus = "Invalid YouTube URL"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.state.isDownloading = false
                self?.state.downloadStatus = ""
            }
            return
        }
        guard let ytdlp = Self.findExecutable("yt-dlp") else {
            state.isDownloading = true
            state.downloadStatus = "yt-dlp not found — run: brew install yt-dlp"
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.state.isDownloading = false
                self?.state.downloadStatus = ""
            }
            return
        }

        state.isDownloading = true
        state.downloadProgress = 0
        state.downloadStatus = "Starting download…"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            VideoLibrary.shared.ensureReady()
            let libraryPath = VideoLibrary.shared.libraryPath
            let task = Process()
            task.executableURL = URL(fileURLWithPath: ytdlp)
            task.arguments = [
                "-f", "bestvideo+bestaudio/best",
                "--merge-output-format", "mp4",
                "-o", (libraryPath as NSString).appendingPathComponent("%(title)s.%(ext)s"),
                "--no-playlist",
                "--concurrent-fragments", "8",
                "--progress",
                "--newline",
                urlString
            ]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
                for line in output.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.contains("[download]") && trimmed.contains("%") {
                        let cleaned = trimmed.replacingOccurrences(of: "[download]", with: "").trimmingCharacters(in: .whitespaces)
                        if let pctEnd = cleaned.firstIndex(of: "%") {
                            let pctStr = cleaned[cleaned.startIndex..<pctEnd].trimmingCharacters(in: .whitespaces)
                            if let pct = Double(pctStr) {
                                DispatchQueue.main.async {
                                    self?.state.downloadProgress = pct / 100.0
                                    self?.state.downloadStatus = "Downloading… \(Int(pct))%"
                                }
                            }
                        }
                    } else if trimmed.contains("[Merger]") || trimmed.contains("[Merging]") {
                        DispatchQueue.main.async {
                            self?.state.downloadProgress = 0.95
                            self?.state.downloadStatus = "Merging audio and video…"
                        }
                    }
                }
            }

            do {
                try task.run(); task.waitUntilExit()
                pipe.fileHandleForReading.readabilityHandler = nil
                if task.terminationStatus == 0 {
                    let fm = FileManager.default
                    let newest = VideoLibrary.shared.videoFiles()
                        .compactMap { url -> (URL, Date)? in
                            guard let attrs = try? fm.attributesOfItem(atPath: url.path),
                                  let mod = attrs[.modificationDate] as? Date else { return nil }
                            return (url, mod)
                        }
                        .sorted { $0.1 > $1.1 }
                        .first?.0
                    DispatchQueue.main.async {
                        self?.state.downloadProgress = 1.0
                        self?.state.downloadStatus = "Download complete! Processing…"
                        self?.state.youtubeURL = ""
                        if let downloadedFile = newest {
                            self?.processAndImportVideo(sourceURL: downloadedFile)
                        } else {
                            self?.state.isDownloading = false
                            self?.state.downloadProgress = 0
                            self?.state.downloadStatus = ""
                            self?.state.refresh()
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.state.isDownloading = false
                        self?.state.downloadStatus = "Download failed"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self?.state.downloadStatus = ""
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.state.isDownloading = false
                    self?.state.downloadStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    private static func findExecutable(_ name: String) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "\(home)/.livepaper/bin/\(name)"
        ]
        for p in paths where FileManager.default.fileExists(atPath: p) { return p }
        return nil
    }

    private func pickVideo(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .avi]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }
}
