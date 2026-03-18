import Cocoa

class SettingsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    // MARK: - Layout

    private let SW: CGFloat = 160   // sidebar width
    private let WW: CGFloat = 560   // window width
    private let WH: CGFloat = 400   // window height
    private var CW: CGFloat { WW - SW - 1 }

    // MARK: - Views

    private let sidebar     = NSView()
    private let contentArea = NSView()
    private var sidebarBtns: [SidebarBtn] = []

    // General
    private let enableToggle = NSButton(checkboxWithTitle: "WinTab 활성화 / Enable WinTab", target: nil, action: nil)
    private let loginToggle  = NSButton(checkboxWithTitle: "로그인 시 자동 실행 / Launch at Login", target: nil, action: nil)

    // Shortcuts
    private let altTabToggle = NSButton(checkboxWithTitle: "AltTab 연동 / AltTab Integration", target: nil, action: nil)

    // Exclude
    private var excludeApps: [String] = []
    private let excludeTable = NSTableView()
    private lazy var excludeScrollView: NSScrollView = {
        let sv = NSScrollView()
        sv.hasVerticalScroller  = true
        sv.autohidesScrollers   = true
        sv.borderType           = .bezelBorder
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col"))
        excludeTable.addTableColumn(col)
        excludeTable.headerView  = nil
        excludeTable.dataSource  = self
        excludeTable.delegate    = self
        excludeTable.rowHeight   = 28
        excludeTable.usesAlternatingRowBackgroundColors = true
        sv.documentView = excludeTable
        return sv
    }()
    private let excludeField = NSTextField()

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: WW, height: WH))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildSidebar()
        buildContentArea()
        loadSettings()
        switchPage(0)
    }

    // MARK: - Sidebar

    private func buildSidebar() {
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = NSColor(white: 0.95, alpha: 1).cgColor
        sidebar.frame = NSRect(x: 0, y: 0, width: SW, height: WH)
        view.addSubview(sidebar)

        // Icon
        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: "square.on.square", accessibilityDescription: nil) {
            iconView.image = img.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 30, weight: .medium))
        }
        iconView.contentTintColor = .systemBlue
        iconView.frame = NSRect(x: (SW - 36) / 2, y: WH - 70, width: 36, height: 36)
        sidebar.addSubview(iconView)

        // App name
        let nameLabel = NSTextField(labelWithString: "WinTab")
        nameLabel.font      = NSFont.boldSystemFont(ofSize: 14)
        nameLabel.textColor = .labelColor
        nameLabel.alignment = .center
        nameLabel.frame     = NSRect(x: 0, y: WH - 96, width: SW, height: 20)
        sidebar.addSubview(nameLabel)

        let versionLabel = NSTextField(labelWithString: "v1.0.0")
        versionLabel.font      = NSFont.systemFont(ofSize: 10)
        versionLabel.textColor = .tertiaryLabelColor
        versionLabel.alignment = .center
        versionLabel.frame     = NSRect(x: 0, y: WH - 114, width: SW, height: 14)
        sidebar.addSubview(versionLabel)

        // Separator
        let sep = NSBox(); sep.boxType = .separator
        sep.frame = NSRect(x: 12, y: WH - 126, width: SW - 24, height: 1)
        sidebar.addSubview(sep)

        // Navigation items
        let items: [(String, String)] = [
            ("일반",   "gearshape"),
            ("단축키", "keyboard"),
            ("제외 앱", "xmark.circle"),
        ]
        let startY: CGFloat = WH - 172
        items.enumerated().forEach { i, item in
            let btn = SidebarBtn(title: item.0, icon: item.1, tag: i)
            btn.frame  = NSRect(x: 8, y: startY - CGFloat(i) * 42, width: SW - 16, height: 36)
            btn.target = self
            btn.action = #selector(sidebarTapped(_:))
            sidebar.addSubview(btn)
            sidebarBtns.append(btn)
        }

        // Divider between sidebar and content
        let divider = NSBox(); divider.boxType = .separator
        divider.frame = NSRect(x: SW, y: 0, width: 1, height: WH)
        view.addSubview(divider)
    }

    private func buildContentArea() {
        contentArea.frame = NSRect(x: SW + 1, y: 0, width: CW, height: WH)
        view.addSubview(contentArea)
    }

    @objc private func sidebarTapped(_ sender: NSButton) { switchPage(sender.tag) }

    private func switchPage(_ idx: Int) {
        sidebarBtns.enumerated().forEach { i, btn in btn.setSelected(i == idx) }
        contentArea.subviews.forEach { $0.removeFromSuperview() }
        let page: NSView
        switch idx {
        case 0: page = buildGeneralPage()
        case 1: page = buildShortcutsPage()
        case 2: page = buildExcludePage()
        default: return
        }
        page.frame = NSRect(x: 0, y: 0, width: CW, height: WH)
        contentArea.addSubview(page)
    }

    // MARK: - General Page

    private func buildGeneralPage() -> NSView {
        let page = NSView()

        let title = pageTitle("일반")
        title.frame = NSRect(x: 24, y: WH - 52, width: 200, height: 24)
        page.addSubview(title)

        // Enable toggle card
        let enableCard = makeCard(y: WH - 132, h: 66)
        enableToggle.frame  = NSRect(x: 14, y: 38, width: CW - 48, height: 18)
        enableToggle.target = self; enableToggle.action = #selector(save)
        let d1 = makeDesc("단축키 변환 기능을 활성화합니다.")
        d1.frame = NSRect(x: 33, y: 16, width: CW - 66, height: 14)
        enableCard.addSubview(enableToggle); enableCard.addSubview(d1)
        page.addSubview(enableCard)

        // Login toggle card
        let loginCard = makeCard(y: WH - 216, h: 66)
        loginToggle.frame   = NSRect(x: 14, y: 38, width: CW - 48, height: 18)
        loginToggle.target  = self; loginToggle.action = #selector(save)
        let d2 = makeDesc("Mac 시작 시 WinTab을 자동으로 실행합니다.")
        d2.frame = NSRect(x: 33, y: 16, width: CW - 66, height: 14)
        loginCard.addSubview(loginToggle); loginCard.addSubview(d2)
        page.addSubview(loginCard)

        // Accessibility button
        let accessBtn = NSButton(title: " 손쉬운 사용 설정", target: self, action: #selector(openAccessibility))
        accessBtn.image         = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: nil)
        accessBtn.imagePosition = .imageLeft
        accessBtn.bezelStyle    = .rounded
        accessBtn.contentTintColor = .systemGray
        accessBtn.frame         = NSRect(x: 16, y: 58, width: 160, height: 28)
        page.addSubview(accessBtn)

        // Bottom buttons
        let githubBtn = NSButton(title: " GitHub", target: self, action: #selector(openGitHub))
        githubBtn.image         = NSImage(systemSymbolName: "arrow.up.right.square", accessibilityDescription: nil)
        githubBtn.imagePosition = .imageLeft
        githubBtn.bezelStyle    = .rounded
        githubBtn.frame         = NSRect(x: 16, y: 16, width: 106, height: 28)
        page.addSubview(githubBtn)

        let donateBtn = NSButton(title: "☕ 후원하기", target: self, action: #selector(openDonate))
        donateBtn.bezelStyle        = .rounded
        donateBtn.contentTintColor  = .systemOrange
        donateBtn.frame             = NSRect(x: 130, y: 16, width: 106, height: 28)
        page.addSubview(donateBtn)

        let sv = makeSaveButton()
        sv.frame = NSRect(x: CW - 92, y: 16, width: 76, height: 28)
        page.addSubview(sv)

        return page
    }

    // MARK: - Shortcuts Page

    private func buildShortcutsPage() -> NSView {
        let page = NSView()

        let title = pageTitle("단축키")
        title.frame = NSRect(x: 24, y: WH - 52, width: 200, height: 24)
        page.addSubview(title)

        // How it works info box
        let infoBox = NSBox()
        infoBox.boxType       = .custom
        infoBox.fillColor     = NSColor.systemBlue.withAlphaComponent(0.07)
        infoBox.borderColor   = NSColor.systemBlue.withAlphaComponent(0.22)
        infoBox.borderWidth   = 0.5
        infoBox.cornerRadius  = 10
        infoBox.frame         = NSRect(x: 16, y: WH - 230, width: CW - 32, height: 160)

        let infoTitle = NSTextField(labelWithString: "⌨️  작동 방식")
        infoTitle.font      = NSFont.boldSystemFont(ofSize: 11)
        infoTitle.textColor = .systemBlue
        infoTitle.frame     = NSRect(x: 14, y: 130, width: 200, height: 16)
        infoBox.addSubview(infoTitle)

        let rows: [(String, String)] = [
            ("Ctrl + Tab",         "→  다음 탭  (⌘⇧])"),
            ("Ctrl + Shift + Tab", "→  이전 탭  (⌘⇧[)"),
            ("Alt + Tab",          "→  앱 전환  (AltTab / ⌘Tab)"),
        ]
        rows.enumerated().forEach { i, row in
            let k = NSTextField(labelWithString: row.0)
            k.font  = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
            k.frame = NSRect(x: 14, y: 98 - CGFloat(i) * 30, width: 170, height: 18)
            infoBox.addSubview(k)

            let v = NSTextField(labelWithString: row.1)
            v.font      = NSFont.systemFont(ofSize: 11)
            v.textColor = .secondaryLabelColor
            v.frame     = NSRect(x: 188, y: 98 - CGFloat(i) * 30, width: CW - 230, height: 18)
            infoBox.addSubview(v)
        }
        page.addSubview(infoBox)

        // AltTab card (Karabiner 안내 포함)
        let altCard = makeCard(y: WH - 338, h: 90)
        altTabToggle.frame  = NSRect(x: 14, y: 58, width: CW - 48, height: 18)
        altTabToggle.target = self; altTabToggle.action = #selector(save)
        let da1 = makeDesc("ON: AltTab 앱이 Alt+Tab을 직접 처리합니다.")
        da1.frame = NSRect(x: 33, y: 37, width: CW - 66, height: 14)
        let da2 = makeDesc("OFF: macOS 기본 Command+Tab 앱전환으로 동작합니다.")
        da2.frame = NSRect(x: 33, y: 18, width: CW - 66, height: 14)
        altCard.addSubview(altTabToggle)
        altCard.addSubview(da1)
        altCard.addSubview(da2)
        page.addSubview(altCard)

        let sv = makeSaveButton()
        sv.frame = NSRect(x: CW - 92, y: 16, width: 76, height: 28)
        page.addSubview(sv)

        return page
    }

    // MARK: - Exclude Page

    private func buildExcludePage() -> NSView {
        let page = NSView()

        let title = pageTitle("제외 앱")
        title.frame = NSRect(x: 24, y: WH - 52, width: 200, height: 24)
        page.addSubview(title)

        let sub = makeDesc("아래 앱에서는 Ctrl+Tab 변환이 비활성화됩니다.")
        sub.frame = NSRect(x: 24, y: WH - 76, width: CW - 48, height: 16)
        page.addSubview(sub)

        // Table
        excludeScrollView.frame = NSRect(x: 16, y: 108, width: CW - 32, height: WH - 200)
        page.addSubview(excludeScrollView)

        // Input + Add
        excludeField.placeholderString = "com.apple.Safari"
        excludeField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        excludeField.frame = NSRect(x: 16, y: 72, width: CW - 94, height: 26)
        page.addSubview(excludeField)

        let addBtn = NSButton(title: "+ 추가", target: self, action: #selector(addExcludeApp))
        addBtn.bezelStyle = .rounded
        addBtn.frame      = NSRect(x: CW - 74, y: 72, width: 58, height: 26)
        page.addSubview(addBtn)

        // Remove
        let removeBtn = NSButton(title: "− 선택 제거", target: self, action: #selector(removeExcludeApp))
        removeBtn.bezelStyle = .rounded
        removeBtn.frame      = NSRect(x: 16, y: 36, width: 100, height: 26)
        page.addSubview(removeBtn)

        let sv = makeSaveButton()
        sv.frame = NSRect(x: CW - 92, y: 36, width: 76, height: 28)
        page.addSubview(sv)

        return page
    }

    // MARK: - UI Helpers

    private func pageTitle(_ text: String) -> NSTextField {
        let tf = NSTextField(labelWithString: text)
        tf.font      = NSFont.boldSystemFont(ofSize: 16)
        tf.textColor = .labelColor
        return tf
    }

    private func makeDesc(_ text: String) -> NSTextField {
        let tf = NSTextField(labelWithString: text)
        tf.font      = NSFont.systemFont(ofSize: 11)
        tf.textColor = .secondaryLabelColor
        return tf
    }

    private func makeCard(y: CGFloat, h: CGFloat) -> NSView {
        let v = NSView(frame: NSRect(x: 16, y: y, width: CW - 32, height: h))
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor(white: 0.97, alpha: 1).cgColor
        v.layer?.cornerRadius    = 10
        v.layer?.borderColor     = NSColor(white: 0.84, alpha: 1).cgColor
        v.layer?.borderWidth     = 0.5
        return v
    }

    private func makeSaveButton() -> NSButton {
        let btn = NSButton(title: "저장", target: self, action: #selector(save))
        btn.bezelStyle    = .rounded
        btn.keyEquivalent = "\r"
        return btn
    }

    // MARK: - Logic

    private func loadSettings() {
        let s = Settings.shared
        enableToggle.state  = s.enabled           ? .on : .off
        loginToggle.state   = s.launchAtLogin     ? .on : .off
        altTabToggle.state  = s.altTabIntegration ? .on : .off
        excludeApps = s.excludedApps
        excludeTable.reloadData()
    }

    @objc private func save() {
        let s = Settings.shared
        s.enabled           = enableToggle.state == .on
        s.launchAtLogin     = loginToggle.state  == .on
        s.altTabIntegration = altTabToggle.state == .on
        s.excludedApps      = excludeApps
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }

    @objc private func addExcludeApp() {
        let t = excludeField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !excludeApps.contains(t) else { return }
        excludeApps.append(t)
        excludeTable.reloadData()
        excludeField.stringValue = ""
    }

    @objc private func removeExcludeApp() {
        let row = excludeTable.selectedRow
        guard row >= 0 else { return }
        excludeApps.remove(at: row)
        excludeTable.reloadData()
    }

    @objc private func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/asdcxs/winTab")!)
    }

    @objc private func openDonate() {
        NSWorkspace.shared.open(URL(string: "https://buymeacoffee.com/asdcxs")!)
    }

    // MARK: - TableView

    func numberOfRows(in tableView: NSTableView) -> Int { excludeApps.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTableCellView()
        let tf   = NSTextField(labelWithString: excludeApps[row])
        tf.font  = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        tf.frame = NSRect(x: 8, y: 6, width: tableView.frame.width - 16, height: 16)
        cell.addSubview(tf)
        return cell
    }
}

// MARK: - SidebarBtn

class SidebarBtn: NSButton {
    private var selected = false

    init(title: String, icon: String, tag: Int) {
        super.init(frame: .zero)
        self.title    = "  \(title)"
        self.tag      = tag
        self.bezelStyle = .inline
        self.isBordered = false
        self.font       = NSFont.systemFont(ofSize: 13)
        self.alignment  = .left
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            self.image         = img
            self.imagePosition = .imageLeft
            self.imageHugsTitle = true
        }
        self.contentTintColor = .secondaryLabelColor
    }

    required init?(coder: NSCoder) { fatalError() }

    func setSelected(_ sel: Bool) {
        selected = sel
        contentTintColor = sel ? .systemBlue : .secondaryLabelColor
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if selected {
            NSColor.systemBlue.withAlphaComponent(0.13).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 6, yRadius: 6).fill()
        }
        super.draw(dirtyRect)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let settingsChanged = Notification.Name("com.wintab.settingsChanged")
}
