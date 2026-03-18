import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var eventTapManager: EventTapManager!
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 메뉴바 아이콘
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "square.on.square", accessibilityDescription: "WinTab")
            img?.isTemplate = true
            button.image = img
            button.toolTip = "WinTab"
        }

        setupMenu()
        ClipboardManager.shared.start()

        // 손쉬운 사용 권한 확인
        if !AXIsProcessTrusted() {
            requestAccessibilityPermission()
        } else {
            startEventTap()
        }
    }

    func setupMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "WinTab", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "설정 / Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "🔄 EventTap 재시작", action: #selector(restartEventTap), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "종료 / Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc func restartEventTap() {
        eventTapManager?.stop()
        eventTapManager = nil
        if AXIsProcessTrusted() {
            startEventTap()
        } else {
            requestAccessibilityPermission()
        }
    }

    func startEventTap() {
        eventTapManager = EventTapManager()
        eventTapManager.start()
    }

    func requestAccessibilityPermission() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)

        // 권한 허용될 때까지 2초마다 반복 체크 (최대 60초)
        var attempts = 0
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            attempts += 1
            if AXIsProcessTrusted() {
                timer.invalidate()
                self.startEventTap()
            } else if attempts >= 30 {
                timer.invalidate()
            }
        }
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let vc = SettingsViewController()
            settingsWindow = NSWindow(contentViewController: vc)
            settingsWindow?.title = "WinTab 설정"
            settingsWindow?.setContentSize(NSSize(width: 560, height: 420))
            settingsWindow?.styleMask = [.titled, .closable]
            settingsWindow?.center()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
