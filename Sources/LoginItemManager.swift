// LivePaper – Launch at Login via SMAppService

import Foundation
import ServiceManagement

enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            NSLog("LivePaper: Launch at login → %d", enabled ? 1 : 0)
            return true
        } catch {
            NSLog("LivePaper: Launch at login failed: %@", error.localizedDescription)
            return false
        }
    }
}
