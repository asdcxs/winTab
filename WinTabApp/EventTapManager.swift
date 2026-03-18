import Cocoa
import CoreGraphics

// Ctrl+key → Cmd+key 로 변환할 키코드 목록
private let windowsShortcutKeyCodes: Set<Int64> = [
    0,  // A - 전체선택
    1,  // S - 저장
    3,  // F - 찾기
    6,  // Z - 실행취소
    7,  // X - 잘라내기
    8,  // C - 복사
    9,  // V - 붙여넣기
    13, // W - 탭 닫기
    15, // R - 새로고침
    17, // T - 새 탭
    35, // P - 인쇄
    45, // N - 새 창
]

class EventTapManager {
    var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        NotificationCenter.default.addObserver(self, selector: #selector(onSettingsChanged), name: .settingsChanged, object: nil)
        createTap()
    }

    private func createTap() {
        let mask: UInt64 = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.scrollWheel.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)
            | (1 << CGEventType.otherMouseUp.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
        let eventMask = CGEventMask(mask)

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

    let s = Settings.shared
    guard s.enabled else { return Unmanaged.passRetained(event) }

    // 제외 앱 확인
    if let frontApp = NSWorkspace.shared.frontmostApplication,
       let bundleId = frontApp.bundleIdentifier,
       s.excludedApps.contains(bundleId) {
        return Unmanaged.passRetained(event)
    }

    // 마우스 스크롤 방향 반전 (마우스 휠만, 트랙패드 제외)
    if type == .scrollWheel && s.reverseScroll {
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)
        if isContinuous == 0 {
            let dy = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            let dx = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
            event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -dy)
            event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -dx)
            let pdy = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
            let pdx = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
            event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: -pdy)
            event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: -pdx)
            let fdy = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
            let fdx = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fdy)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -fdx)
        }
        return Unmanaged.passRetained(event)
    }

    // 마우스 4/5번 버튼 → 뒤로가기/앞으로가기 (Cmd+[ / Cmd+])
    if (type == .otherMouseDown || type == .otherMouseUp) && s.mouseNavigation {
        let btn = event.getIntegerValueField(.mouseEventButtonNumber)
        if btn == 3 || btn == 4 {
            let bracketKey: CGKeyCode = btn == 3 ? 33 : 30  // 33=[ 30=]
            guard let navEvent = CGEvent(keyboardEventSource: nil, virtualKey: bracketKey, keyDown: type == .otherMouseDown) else {
                return Unmanaged.passRetained(event)
            }
            navEvent.flags = .maskCommand
            navEvent.post(tap: .cgSessionEventTap)
            return nil
        }
    }

    guard type == .keyDown || type == .keyUp else { return Unmanaged.passRetained(event) }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags   = event.flags
    let hasCommand = flags.contains(.maskCommand)
    let hasShift   = flags.contains(.maskShift)
    let hasControl = flags.contains(.maskControl)
    let hasOption  = flags.contains(.maskAlternate)

    // Ctrl+Shift+V → 클립보드 히스토리 팝업
    if keyCode == 9 && hasControl && hasShift && !hasCommand && !hasOption && type == .keyDown && s.clipboardHistory {
        DispatchQueue.main.async { ClipboardManager.shared.showPopup() }
        return nil
    }

    // Windows 단축키 변환 (Ctrl+key → Cmd+key)
    if hasControl && !hasCommand && !hasOption && s.windowsShortcuts && windowsShortcutKeyCodes.contains(keyCode) {
        var newFlags: CGEventFlags = .maskCommand
        if hasShift { newFlags.insert(.maskShift) }
        event.flags = newFlags
        return Unmanaged.passRetained(event)
    }

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
            return Unmanaged.passRetained(event)
        } else {
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
