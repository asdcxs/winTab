import Cocoa
import CoreGraphics

class EventTapManager {
    var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        NotificationCenter.default.addObserver(self, selector: #selector(onSettingsChanged), name: .settingsChanged, object: nil)
        createTap()
    }

    private func createTap() {
        let eventMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue)
        )

        tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventCallback,
            userInfo: Unmanaged.passRetained(self).toOpaque()
        )

        guard let tap = tap else { return }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
    }

    @objc private func onSettingsChanged() {
        let enabled = Settings.shared.enabled
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: enabled) }
    }
}

private func eventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    if type == .tapDisabledByTimeout {
        if let userInfo = userInfo {
            let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()
            if let tap = manager.tap { CGEvent.tapEnable(tap: tap, enable: true) }
        }
        return Unmanaged.passRetained(event)
    }

    guard type == .keyDown || type == .keyUp else { return Unmanaged.passRetained(event) }

    let s = Settings.shared
    guard s.enabled else { return Unmanaged.passRetained(event) }

    // 제외 앱 확인
    if let frontApp = NSWorkspace.shared.frontmostApplication,
       let bundleId = frontApp.bundleIdentifier,
       s.excludedApps.contains(bundleId) {
        return Unmanaged.passRetained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags   = event.flags
    let hasCommand = flags.contains(.maskCommand)
    let hasShift   = flags.contains(.maskShift)
    let hasControl = flags.contains(.maskControl)
    let hasOption  = flags.contains(.maskAlternate)

    guard keyCode == 48 else { return Unmanaged.passRetained(event) }

    // Command+Tab (물리 Ctrl+Tab) → ⌘⇧] / ⌘⇧[
    if hasCommand, !hasControl, !hasOption {
        let bracketKeyCode: Int64 = hasShift ? 33 : 30
        event.setIntegerValueField(.keyboardEventKeycode, value: bracketKeyCode)
        event.flags = [.maskCommand, .maskShift]
        return Unmanaged.passRetained(event)
    }

    // Control+Tab (물리 Alt+Tab) → AltTab 연동 or 네이티브 앱전환
    if hasControl, !hasCommand, !hasOption {
        if s.altTabIntegration {
            // AltTab이 Control+Tab을 직접 처리하도록 통과
            return Unmanaged.passRetained(event)
        } else {
            // 네이티브 macOS 앱전환
            guard let appSwitchEvent = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(48), keyDown: type == .keyDown) else {
                return Unmanaged.passRetained(event)
            }
            var switchFlags: CGEventFlags = .maskCommand
            if hasShift { switchFlags.insert(.maskShift) }
            appSwitchEvent.flags = switchFlags
            appSwitchEvent.post(tap: .cgSessionEventTap)
            return nil
        }
    }

    return Unmanaged.passRetained(event)
}
