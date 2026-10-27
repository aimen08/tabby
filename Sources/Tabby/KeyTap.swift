import AppKit

/// Global keyboard tap for ⌥Tab. Requires Accessibility permission.
final class KeyTap {
    enum Action { case next, previous, left, right, confirm, cancel, modifierReleased }

    /// Return true to swallow the event.
    private let handler: (Action) -> Bool
    /// When false, every event passes through untouched.
    var isEnabled = true
    private var tap: CFMachPort?

    private enum Key {
        static let tab: Int64 = 48, escape: Int64 = 53, enter: Int64 = 36
        static let left: Int64 = 123, right: Int64 = 124
    }

    init(handler: @escaping (Action) -> Bool) {
        self.handler = handler
    }

    func start() -> Bool {
        if tap != nil { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                let keyTap = Unmanaged<KeyTap>.fromOpaque(refcon!).takeUnretainedValue()
                return keyTap.process(type, event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func process(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        case _ where !isEnabled:
            return pass
        case .flagsChanged:
            // Observe only: never swallow modifier changes.
            if !event.flags.contains(.maskAlternate) { _ = handler(.modifierReleased) }
            return pass
        case .keyDown, .keyUp:
            guard let action = action(for: event) else { return pass }
            // Swallow the matching keyUp too, so the app underneath never sees a stray Tab.
            if type == .keyUp { return isOptionTab(event) ? nil : pass }
            return handler(action) ? nil : pass
        default:
            return pass
        }
    }

    private func isOptionTab(_ event: CGEvent) -> Bool {
        let flags = event.flags
        return event.getIntegerValueField(.keyboardEventKeycode) == Key.tab
            && flags.contains(.maskAlternate)
            && !flags.contains(.maskCommand) && !flags.contains(.maskControl)
    }

    private func action(for event: CGEvent) -> Action? {
        if isOptionTab(event) { return event.flags.contains(.maskShift) ? .previous : .next }
        switch event.getIntegerValueField(.keyboardEventKeycode) {
        case Key.escape: return .cancel
        case Key.enter: return .confirm
        case Key.left: return .left
        case Key.right: return .right
        default: return nil
        }
    }
}
