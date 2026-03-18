import Cocoa
import CoreGraphics

class ClipboardManager {
    static let shared = ClipboardManager()

    private var history: [String] = []
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private var popup: ClipboardPopup?

    let maxHistory = 20

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        guard Settings.shared.clipboardHistory else { return }
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        if let text = pb.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            history.removeAll { $0 == text }
            history.insert(text, at: 0)
            if history.count > maxHistory { history.removeLast() }
        }
    }

    func showPopup() {
        if popup == nil { popup = ClipboardPopup(manager: self) }
        popup?.show()
    }

    func getHistory() -> [String] { history }

    func paste(index: Int) {
        guard index < history.count else { return }
        let text = history[index]
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        lastChangeCount = NSPasteboard.general.changeCount
        popup?.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }
            let down = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
            let up   = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
            down?.flags = .maskCommand
            up?.flags   = .maskCommand
            down?.post(tap: .cgSessionEventTap)
            up?.post(tap: .cgSessionEventTap)
        }
    }
}

// MARK: - Popup Window

class ClipboardPopup: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private var panel: NSPanel?
    private let tableView = NSTableView()
    private weak var manager: ClipboardManager?

    init(manager: ClipboardManager) {
        self.manager = manager
        super.init()
    }

    func show() {
        if panel == nil { buildPanel() }
        tableView.reloadData()
        // 선택된 항목이 없으면 첫 번째 선택
        if tableView.numberOfRows > 0 { tableView.selectRowIndexes([0], byExtendingSelection: false) }
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() { panel?.orderOut(nil) }

    private func buildPanel() {
        let w: CGFloat = 420, h: CGFloat = 360
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = min(mouse.x - w / 2, screen.maxX - w)
        let y = min(max(mouse.y - h - 10, screen.minY), screen.maxY - h)

        panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: w, height: h),
            styleMask: [.titled, .closable, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel?.title = "클립보드 히스토리"
        panel?.level = .floating
        panel?.isReleasedWhenClosed = false
        panel?.hidesOnDeactivate = false

        // Table
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col"))
        col.width = w - 20
        tableView.addTableColumn(col)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.rowHeight  = 40
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.doubleAction = #selector(rowDoubleClicked)
        tableView.target = self

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 48, width: w, height: h - 48))
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers  = true

        // Buttons
        let pasteBtn = NSButton(title: "붙여넣기", target: self, action: #selector(pasteSelected))
        pasteBtn.bezelStyle    = .rounded
        pasteBtn.keyEquivalent = "\r"
        pasteBtn.frame = NSRect(x: w - 100, y: 10, width: 88, height: 28)

        let closeBtn = NSButton(title: "닫기", target: self, action: #selector(closeTapped))
        closeBtn.bezelStyle = .rounded
        closeBtn.frame = NSRect(x: w - 196, y: 10, width: 88, height: 28)

        let clearBtn = NSButton(title: "전체 지우기", target: self, action: #selector(clearAll))
        clearBtn.bezelStyle    = .rounded
        clearBtn.contentTintColor = .systemRed
        clearBtn.frame = NSRect(x: 10, y: 10, width: 100, height: 28)

        panel?.contentView?.addSubview(scroll)
        panel?.contentView?.addSubview(pasteBtn)
        panel?.contentView?.addSubview(closeBtn)
        panel?.contentView?.addSubview(clearBtn)
    }

    @objc private func rowDoubleClicked() { pasteSelected() }

    @objc private func pasteSelected() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        manager?.paste(index: row)
    }

    @objc private func closeTapped() { hide() }

    @objc private func clearAll() {
        // ClipboardManager의 history에 직접 접근 대신 public 메서드 사용
        manager?.clearHistory()
        tableView.reloadData()
    }

    // MARK: - TableView

    func numberOfRows(in tableView: NSTableView) -> Int { manager?.getHistory().count ?? 0 }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let history = manager?.getHistory(), row < history.count else { return nil }
        let text = history[row]

        let cell = NSTableCellView()

        let numLabel = NSTextField(labelWithString: "\(row + 1)")
        numLabel.font      = NSFont.monospacedSystemFont(ofSize: 10, weight: .bold)
        numLabel.textColor = .tertiaryLabelColor
        numLabel.alignment = .center
        numLabel.frame     = NSRect(x: 6, y: 12, width: 20, height: 16)
        cell.addSubview(numLabel)

        let tf = NSTextField(labelWithString: text.replacingOccurrences(of: "\n", with: " "))
        tf.font          = NSFont.systemFont(ofSize: 12)
        tf.lineBreakMode = .byTruncatingTail
        tf.frame         = NSRect(x: 30, y: 12, width: tableView.frame.width - 40, height: 16)
        cell.addSubview(tf)

        return cell
    }
}

// MARK: - ClipboardManager clearHistory

extension ClipboardManager {
    func clearHistory() {
        history.removeAll()
    }
}
