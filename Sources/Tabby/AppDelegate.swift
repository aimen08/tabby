import AppKit
import ServiceManagement
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let apps = RecentApps()
    private let panel = SwitcherPanel()
    private let previews = WindowPreviews()
    private var keyTap: KeyTap!
    private var statusItem: NSStatusItem!
    private let updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    // Current switching session: a snapshot of apps taken when ⌥Tab is first pressed.
    private var session: [NSRunningApplication]?
    private var selected = 0
    private var showWork: DispatchWorkItem?
    /// Set once the mouse is used in the switcher: releasing ⌥ then keeps it open for a click.
    private var usingMouse = false
    private var outsideClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        panel.onClick = { [weak self] index in
            self?.selected = index
            self?.commit()
        }
        panel.onHover = { [weak self] index in
            guard let self, self.session != nil else { return }
            self.usingMouse = true
            self.selected = index
            self.panel.select(index)
        }
        // A click anywhere else closes a switcher that was left open for the mouse.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.session != nil { self?.end() }
        }
        panel.onQuit = { $0.terminate() }
        panel.onForceQuit = { $0.forceTerminate() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.removeFromSession(app.processIdentifier)
            }
        }
        keyTap = KeyTap { [weak self] action in self?.handle(action) ?? false }
        waitForAccessibility()
        // Without Screen Recording the switcher still works, showing app icons instead of previews.
        if !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }
    }

    // MARK: - Accessibility

    private func waitForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options), keyTap.start() {
            NSLog("Tabby: key tap installed")
            return
        }
        NSLog("Tabby: waiting for Accessibility permission")
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self, AXIsProcessTrusted(), self.keyTap.start() else { return }
            timer.invalidate()
            NSLog("Tabby: key tap installed")
        }
    }

    // MARK: - Switching

    /// Returns true when the key event should be swallowed.
    private func handle(_ action: KeyTap.Action) -> Bool {
        switch action {
        case .next, .previous:
            let step = action == .next ? 1 : -1
            if let session {
                selected = (selected + step + session.count) % session.count
                panel.select(selected)
            } else {
                begin(step: step)
            }
            return true
        case .left, .right:
            guard let session else { return false }
            selected = (selected + (action == .right ? 1 : -1) + session.count) % session.count
            panel.select(selected)
            return true
        case .confirm, .modifierReleased:
            guard session != nil else { return false }
            if action == .modifierReleased, usingMouse, panel.isVisible { return false }
            commit()
            return action == .confirm
        case .cancel:
            guard session != nil else { return false }
            end()
            return true
        }
    }

    private func begin(step: Int) {
        let list = apps.ordered()
        guard !list.isEmpty else { return }
        session = list
        previews.refresh(list) { [weak self] pid, image in
            self?.panel.setPreview(image, for: pid)
        }
        // Index 0 is the frontmost app, so ⌥Tab lands on the previous one.
        selected = list.count == 1 ? 0 : (step + list.count) % list.count
        // A quick ⌥Tab tap switches without flashing the panel.
        let work = DispatchWorkItem { [weak self] in
            guard let self, let session = self.session else { return }
            self.panel.show(session, selected: self.selected, previews: self.previews.cached)
        }
        showWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func commit() {
        guard let session, session.indices.contains(selected) else { return end() }
        let target = session[selected]
        end()
        activate(target)
    }

    /// Drops an app that quit while the switcher is open, keeping the selection in place.
    private func removeFromSession(_ pid: pid_t) {
        guard var list = session, let index = list.firstIndex(where: { $0.processIdentifier == pid }) else { return }
        list.remove(at: index)
        guard !list.isEmpty else { return end() }
        session = list
        if index < selected || selected == list.count { selected -= 1 }
        if panel.isVisible { panel.show(list, selected: selected, previews: previews.cached) }
    }

    private func end() {
        showWork?.cancel()
        showWork = nil
        session = nil
        usingMouse = false
        panel.hide()
    }

    private func activate(_ target: NSRunningApplication) {
        if target.isHidden { target.unhide() }
        target.activate(options: [.activateAllWindows])
        // A background app's activation request can be ignored; Accessibility makes it stick.
        let element = AXUIElementCreateApplication(target.processIdentifier)
        AXUIElementSetAttributeValue(element, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "Tabby")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// Rebuilt each time it opens so the status is always current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let accessibility = AXIsProcessTrusted()
        let screenRecording = CGPreflightScreenCaptureAccess()

        let status = !keyTap.isEnabled ? "Tabby is paused"
            : accessibility ? "Tabby is running — hold ⌥ and press Tab"
            : "Tabby needs Accessibility to work"
        menu.addItem(withTitle: status, action: nil, keyEquivalent: "").isEnabled = false

        let toggle = menu.addItem(withTitle: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        toggle.state = keyTap.isEnabled ? .on : .off

        menu.addItem(.separator())
        addPermissionItem(to: menu, title: "Accessibility", granted: accessibility, pane: "Privacy_Accessibility")
        addPermissionItem(to: menu, title: "Screen Recording (previews)", granted: screenRecording, pane: "Privacy_ScreenCapture")

        menu.addItem(.separator())
        let login = menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        let update = menu.addItem(withTitle: "Check for Updates…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        update.target = updater
        menu.addItem(withTitle: "About Tabby", action: #selector(showAbout), keyEquivalent: "").target = self

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Tabby", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSLog("Tabby: launch at login failed: \(error)")
        }
    }

    @objc private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: NSAttributedString(string: "A minimal ⌥Tab app switcher.\ngithub.com/aimen08/tabby")])
    }

    private func addPermissionItem(to menu: NSMenu, title: String, granted: Bool, pane: String) {
        let item = menu.addItem(withTitle: granted ? "\(title): granted" : "Grant \(title)…",
                                action: granted ? nil : #selector(openPrivacySettings(_:)), keyEquivalent: "")
        item.target = self
        item.state = granted ? .on : .off
        item.isEnabled = !granted
        item.representedObject = pane
    }

    @objc private func toggleEnabled() {
        keyTap.isEnabled.toggle()
        if !keyTap.isEnabled { end() }
        statusItem.button?.appearsDisabled = !keyTap.isEnabled
    }

    @objc private func openPrivacySettings(_ sender: NSMenuItem) {
        guard let pane = sender.representedObject as? String,
              let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}
