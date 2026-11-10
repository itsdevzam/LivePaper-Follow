// LivePaper – Window Persistence Manager
// Only fixes windows that disappeared. Never orderFront healthy windows (flicker).

import AppKit

class WindowPersistenceManager {
    private var timer: Timer?
    private weak var app: LivePaperApp?

    init(app: LivePaperApp) { self.app = app }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let app = self?.app else { return }
            if app.screensaverController?.isActive == true { return }
            let wp = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            let ck = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 2)
            for w in app.wallpaperWindows {
                if w.level != wp { w.level = wp }
                // isVisible can be false when fully covered — that is OK; do not orderFront
                // unless the window was actually ordered out (not on screen list).
                if w.screen == nil || !NSApp.windows.contains(w) {
                    w.orderFront(nil)
                }
            }
            for w in app.clockWindows {
                if w.level != ck { w.level = ck }
                if w.screen == nil || !NSApp.windows.contains(w) {
                    w.orderFront(nil)
                }
            }
        }
        timer?.tolerance = 10
    }
    func stop() { timer?.invalidate() }
}
