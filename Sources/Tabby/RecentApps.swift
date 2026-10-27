import AppKit

/// Regular (Dock-visible) apps in most-recently-used order.
final class RecentApps {
    private var pids: [pid_t] = []

    init() {
        let workspace = NSWorkspace.shared
        pids = workspace.runningApplications.filter(Self.isSwitchable).map(\.processIdentifier)
        if let front = workspace.frontmostApplication { moveToFront(front) }

        let center = workspace.notificationCenter
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            if let app = Self.app(in: note) { self?.moveToFront(app) }
        }
        center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let app = Self.app(in: note), Self.isSwitchable(app),
                  !self.pids.contains(app.processIdentifier) else { return }
            self.pids.append(app.processIdentifier)
        }
        center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            if let app = Self.app(in: note) { self?.pids.removeAll { $0 == app.processIdentifier } }
        }
    }

    func ordered() -> [NSRunningApplication] {
        pids.compactMap(NSRunningApplication.init(processIdentifier:)).filter { !$0.isTerminated && Self.isSwitchable($0) }
    }

    private func moveToFront(_ app: NSRunningApplication) {
        guard Self.isSwitchable(app) else { return }
        pids.removeAll { $0 == app.processIdentifier }
        pids.insert(app.processIdentifier, at: 0)
    }

    private static func isSwitchable(_ app: NSRunningApplication) -> Bool {
        app.activationPolicy == .regular && app != NSRunningApplication.current
    }

    private static func app(in note: Notification) -> NSRunningApplication? {
        note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    }
}
