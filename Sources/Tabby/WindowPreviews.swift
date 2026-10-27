import AppKit
import ScreenCaptureKit

/// Captures a thumbnail of each app's frontmost window. Requires Screen Recording permission.
final class WindowPreviews {
    private var cache: [pid_t: NSImage] = [:]
    private let maxPixelWidth: CGFloat = 640

    func cached(_ pid: pid_t) -> NSImage? { cache[pid] }

    /// Captures fresh previews; `update` is called on the main thread as each one arrives.
    func refresh(_ apps: [NSRunningApplication], update: @escaping (pid_t, NSImage) -> Void) {
        guard CGPreflightScreenCaptureAccess() else { return }
        let pids = Set(apps.map(\.processIdentifier))
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: false) { [weak self] content, _ in
            guard let self, let content else { return }
            for window in Self.frontmostWindows(content.windows, pids: pids) {
                self.capture(window, update: update)
            }
        }
    }

    private func capture(_ window: SCWindow, update: @escaping (pid_t, NSImage) -> Void) {
        guard let pid = window.owningApplication?.processID else { return }
        let config = SCStreamConfiguration()
        let scale = min(2, maxPixelWidth / window.frame.width)
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        let filter = SCContentFilter(desktopIndependentWindow: window)
        SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { [weak self] image, _ in
            guard let image else { return }
            let preview = NSImage(cgImage: image, size: window.frame.size)
            DispatchQueue.main.async {
                self?.cache[pid] = preview
                update(pid, preview)
            }
        }
    }

    /// Picks each app's highest on-screen window. Minimized windows and ones on other Spaces
    /// capture as blank, so those apps keep their last preview (or their icon).
    private static func frontmostWindows(_ windows: [SCWindow], pids: Set<pid_t>) -> [SCWindow] {
        let onScreen = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var zOrder: [CGWindowID: Int] = [:]
        for (index, info) in onScreen.enumerated() {
            if let id = info[kCGWindowNumber as String] as? CGWindowID { zOrder[id] = index }
        }

        var best: [pid_t: SCWindow] = [:]
        for window in windows {
            guard let pid = window.owningApplication?.processID, pids.contains(pid),
                  window.windowLayer == 0, window.frame.width > 120, window.frame.height > 80 else { continue }
            guard let rank = zOrder[window.windowID] else { continue }
            if let current = best[pid], let currentRank = zOrder[current.windowID], currentRank <= rank { continue }
            best[pid] = window
        }
        return Array(best.values)
    }
}
