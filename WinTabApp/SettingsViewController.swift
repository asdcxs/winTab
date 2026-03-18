import Cocoa

class SettingsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    // MARK: - Layout

    private let SW: CGFloat = 160   // sidebar width
    private let WW: CGFloat = 560   // window width
    private let WH: CGFloat = 420   // window height
    private var CW: CGFloat { WW - SW - 1 }

    // MARK: - Views

    private let sidebar     = NSView()
    private let contentArea = NSView()
    private var sidebarBtns: [SidebarBtn] = []

    // General
    private let enableToggle = NSButton(checkboxWithTitle: "WinTab 활성화 / Enable WinTab", target: nil, action: nil)
    private let loginToggle  = NSButton(checkboxWithTitle: "로그인 시 자동 실행 / Launch at Login", target: nil, action: nil)

    // Shortcuts
    private let altTabToggle       = NSButton(checkboxWithTitle: "AltTab 연동 / AltTab Integration", target: nil, action: nil)
    private let windowsShortcutsToggle = NSButton(checkboxWithTitle: "Windows 단축키 프리셋 / Windows Shortcut Preset", target: nil, action: nil)

    // Mouse
    private let reverseScrollToggle    = NSButton(checkboxWithTitle: "마우스 스크롤 방향 반전 / Reverse Scroll", target: nil, action: nil)
    private let mouseNavigationToggle  = NSButton(checkboxWithTitle: "마우스 뒤로/앞으로 버튼 / Mouse Back/Forward", target: nil, action: nil)

    // Clipboard
    private let clipboardHistoryToggle = NSButton(checkboxWithTitle: "클립보드 히스토리 / Clipboard History", target: nil, action: nil)

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

        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: "square.on.square", accessibilityDescription: nil) {
            iconView.image = img.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 30, weight: .medium))
        }
        iconView.contentTintColor = .systemBlue
        iconView.frame = NSRect(x: (SW - 36) / 2, y: WH - 70, width: 36, height: 36)
        sidebar.addSubview(iconView)

        let nameLabel = NSTextField(labelWithString: "WinTab")
        nameLabel.font      = NSFont.boldSystemFont(ofSize: 14)
        nameLabel.textColor = .labelColor
        nameLabel.alignment = .center
        nameLabel.frame     = NSRect(x: 0, y: WH - 96, width: SW, height: 20)
        sidebar.addSubview(nameLabel)

        let versionLabel = NSTextField(labelWithString: "v1.1.0")
        versionLabel.font      = NSFont.systemFont(ofSize: 10)
        versionLabel.textColor = .tertiaryLabelColor
        versionLabel.alignment = .center
        versionLabel.frame     = NSRect(x: 0, y: WH - 114, width: SW, height: 14)
        sidebar.addSubview(versionLabel)

        let sep = NSBox(); sep.boxType = .separator
        sep.frame = NSRect(x: 12, y: WH - 126, width: SW - 24, height: 1)
        sidebar.addSubview(sep)

        let items: [(String, String)] = [
            ("일반",    "gearshape"),
            ("단축키",  "keyboard"),
            ("마우스",  "computermouse"),
            ("클립보드", "doc.on.clipboard"),
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
        case 2: page = buildMousePage()
        case 3: page = buildClipboardPage()
        case 4: page = buildExcludePage()
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

        let enableCard = makeCard(y: WH - 132, h: 66)
        enableToggle.frame  = NSRect(x: 14, y: 38, width: CW - 48, height: 18)
        enableToggle.target = self; enableToggle.action = #selector(save)
        let d1 = makeDesc("단축키 변환 기능을 활성화합니다.")
        d1.frame = NSRect(x: 33, y: 16, width: CW - 66, height: 14)
        enableCard.addSubview(enableToggle); enableCard.addSubview(d1)
        page.addSubview(enableCard)

        let loginCard = makeCard(y: WH - 216, h: 66)
        loginToggle.frame   = NSRect(x: 14, y: 38, width: CW - 48, height: 18)
        loginToggle.target  = self; loginToggle.action = #selector(save)
        let d2 = makeDesc("Mac 시작 시 WinTab을 자동으로 실행합니다.")
        d2.frame = NSRect(x: 33, y: 16, width: CW - 66, height: 14)
        loginCard.addSubview(loginToggle); loginCard.addSubview(d2)
        page.addSubview(loginCard)

        let accessBtn = NSButton(title: " 손쉬운 사용 설정", target: self, action: #selector(openAccessibility))
        accessBtn.image         = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: nil)
        accessBtn.imagePosition = .imageLeft
        accessBtn.bezelStyle    = .rounded
        accessBtn.contentTintColor = .systemGray
        accessBtn.frame         = NSRect(x: 16, y: 58, width: 160, height: 28)
        page.addSubview(accessBtn)

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

        // Windows 단축키 프리셋 카드
        let winCard = makeCard(y: WH - 148, h: 84)
        windowsShortcutsToggle.frame  = NSRect(x: 14, y: 52, width: CW - 48, height: 18)
        windowsShortcutsToggle.target = self; windowsShortcutsToggle.action = #selector(save)
        let dw1 = makeDesc("Ctrl+C/V/X/Z/A/S/W/T/R/F/N → Cmd+C/V/X/Z/A/S/W/T/R/F/N")
        dw1.frame = NSRect(x: 33, y: 32, width: CW - 66, height: 14)
        let dw2 = makeDesc("Karabiner 없이 Windows 스타일 단축키를 사용합니다.")
        dw2.frame = NSRect(x: 33, y: 13, width: CW - 66, height: 14)
        winCard.addSubview(windowsShortcutsToggle)
        winCard.addSubview(dw1); winCard.addSubview(dw2)
        page.addSubview(winCard)

        // 작동 방식 인포박스
        let infoBox = NSBox()
        infoBox.boxType      = .custom
        infoBox.fillColor    = NSColor.systemBlue.withAlphaComponent(0.07)
        infoBox.borderColor  = NSColor.systemBlue.withAlphaComponent(0.22)
        infoBox.borderWidth  = 0.5
        infoBox.cornerRadius = 10
        infoBox.frame        = NSRect(x: 16, y: WH - 308, width: CW - 32, height: 140)

        let infoTitle = NSTextField(labelWithString: "⌨️  탭 전환 작동 방식")
        infoTitle.font      = NSFont.boldSystemFont(ofSize: 11)
        infoTitle.textColor = .systemBlue
        infoTitle.frame     = NSRect(x: 14, y: 110, width: 200, height: 16)
        infoBox.addSubview(infoTitle)

        let rows: [(String, String)] = [
            ("Ctrl + Tab",         "→  다음 탭  (⌘⇧])"),
            ("Ctrl + Shift + Tab", "→  이전 탭  (⌘⇧[)"),
            ("Alt + Tab",          "→  앱 전환  (AltTab / ⌘Tab)"),
        ]
        rows.enumerated().forEach { i, row in
            let k = NSTextField(labelWithString: row.0)
            k.font  = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
            k.frame = NSRect(x: 14, y: 78 - CGFloat(i) * 30, width: 170, height: 18)
            infoBox.addSubview(k)
            let v = NSTextField(labelWithString: row.1)
            v.font      = NSFont.systemFont(ofSize: 11)
            v.textColor = .secondaryLabelColor
            v.frame     = NSRect(x: 188, y: 78 - CGFloat(i) * 30, width: CW - 230, height: 18)
            infoBox.addSubview(v)
        }
        page.addSubview(infoBox)

        // AltTab 카드
        let altCard = makeCard(y: WH - 410, h: 84)
        altTabToggle.frame  = NSRect(x: 14, y: 52, width: CW - 48, height: 18)
        altTabToggle.target = self; altTabToggle.action = #selector(save)
        let da1 = makeDesc("ON: AltTab 앱이 Alt+Tab을 직접 처리합니다.")
        da1.frame = NSRect(x: 33, y: 32, width: CW - 66, height: 14)
        let da2 = makeDesc("OFF: macOS 기본 Command+Tab 앱전환으로 동작합니다.")
        da2.frame = NSRect(x: 33, y: 13, width: CW - 66, height: 14)
        altCard.addSubview(altTabToggle); altCard.addSubview(da1); altCard.addSubview(da2)
        page.addSubview(altCard)

        let sv = makeSaveButton()
        sv.frame = NSRect(x: CW - 92, y: 16, width: 76, height: 28)
        page.addSubview(sv)

        return page
    }

    // MARK: - Mouse Page

    private func buildMousePage() -> NSView {
        let page = NSView()

        let title = pageTitle("마우스")
        title.frame = NSRect(x: 24, y: WH - 52, width: 200, height: 24)
        page.addSubview(title)

        // 스크롤 반전 카드
        let scrollCard = makeCard(y: WH - 148, h: 84)
        reverseScrollToggle.frame  = NSRect(x: 14, y: 52, width: CW - 48, height: 18)
        reverseScrollToggle.target = self; reverseScrollToggle.action = #selector(save)
        let ds1 = makeDesc("마우스 휠 스크롤 방향을 반전합니다. (트랙패드 제외)")
        ds1.frame = NSRect(x: 33, y: 32, width: CW - 66, height: 14)
        let ds2 = makeDesc("Windows 방식: 휠 아래 → 화면 아래로 스크롤")
        ds2.frame = NSRect(x: 33, y: 13, width: CW - 66, height: 14)
        scrollCard.addSubview(reverseScrollToggle); scrollCard.addSubview(ds1); scrollCard.addSubview(ds2)
        page.addSubview(scrollCard)

        // 마우스 뒤로/앞으로 카드
        let navCard = makeCard(y: WH - 250, h: 84)
        mouseNavigationToggle.frame  = NSRect(x: 14, y: 52, width: CW - 48, height: 18)
        mouseNavigationToggle.target = self; mouseNavigationToggle.action = #selector(save)
        let dn1 = makeDesc("마우스 4번 버튼 → 뒤로가기  (⌘[)")
        dn1.frame = NSRect(x: 33, y: 32, width: CW - 66, height: 14)
        let dn2 = makeDesc("마우스 5번 버튼 → 앞으로가기  (⌘])")
        dn2.frame = NSRect(x: 33, y: 13, width: CW - 66, height: 14)
        navCard.addSubview(mouseNavigationToggle); navCard.addSubview(dn1); navCard.addSubview(dn2)
        page.addSubview(navCard)

        let sv = makeSaveButton()
        sv.frame = NSRect(x: CW - 92, y: 16, width: 76, height: 28)
        page.addSubview(sv)

        return page
    }

    // MARK: - Clipboard Page

    private func buildClipboardPage() -> NSView {
        let page = NSView()

        let title = pageTitle("클립보드")
        title.frame = NSRect(x: 24, y: WH - 52, width: 200, height: 24)
        page.addSubview(title)

        // 히스토리 활성화 카드
        let clipCard = makeCard(y: WH - 148, h: 84)
        clipboardHistoryToggle.frame  = NSRect(x: 14, y: 52, width: CW - 48, height: 18)
        clipboardHistoryToggle.target = self; clipboardHistoryToggle.action = #selector(save)
        let dc1 = makeDesc("최근 복사한 텍스트 20개를 저장합니다.")
        dc1.frame = NSRect(x: 33, y: 32, width: CW - 66, height: 14)
        let dc2 = makeDesc("단축키: Ctrl+Shift+V  →  히스토리 팝업 열기")
        dc2.frame = NSRect(x: 33, y: 13, width: CW - 66, height: 14)
        clipCard.addSubview(clipboardHistoryToggle); clipCard.addSubview(dc1); clipCard.addSubview(dc2)
        page.addSubview(clipCard)

        // 안내 인포박스
        let infoBox = NSBox()
        infoBox.boxType      = .custom
        infoBox.fillColor    = NSColor.systemGreen.withAlphaComponent(0.07)
        infoBox.borderColor  = NSColor.systemGreen.withAlphaComponent(0.3)
        infoBox.borderWidth  = 0.5
        infoBox.cornerRadius = 10
        infoBox.frame        = NSRect(x: 16, y: WH - 280, width: CW - 32, height: 110)

        let infoTitle = NSTextField(labelWithString: "📋  사용 방법")
        infoTitle.font      = NSFont.boldSystemFont(ofSize: 11)
        infoTitle.textColor = .systemGreen
        infoTitle.frame     = NSRect(x: 14, y: 82, width: 200, height: 16)
        infoBox.addSubview(infoTitle)

        let hints: [String] = [
            "1. 텍스트를 복사하면 자동으로 히스토리에 저장됩니다.",
            "2. Ctrl+Shift+V 를 누르면 히스토리 팝업이 열립니다.",
            "3. 항목을 선택하고 붙여넣기 또는 더블클릭하세요.",
        ]
        hints.enumerated().forEach { i, hint in
            let tf = makeDesc(hint)
            tf.frame = NSRect(x: 14, y: 58 - CGFloat(i) * 22, width: CW - 60, height: 16)
            infoBox.addSubview(tf)
        }
        page.addSubview(infoBox)

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

        let sub = makeDesc("아래 앱에서는 모든 변환 기능이 비활성화됩니다.")
        sub.frame = NSRect(x: 24, y: WH - 76, width: CW - 48, height: 16)
        page.addSubview(sub)

        excludeScrollView.frame = NSRect(x: 16, y: 108, width: CW - 32, height: WH - 200)
        page.addSubview(excludeScrollView)

        excludeField.placeholderString = "com.apple.Safari"
        excludeField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        excludeField.frame = NSRect(x: 16, y: 72, width: CW - 94, height: 26)
        page.addSubview(excludeField)

        let addBtn = NSButton(title: "+ 추가", target: self, action: #selector(addExcludeApp))
        addBtn.bezelStyle = .rounded
        addBtn.frame      = NSRect(x: CW - 74, y: 72, width: 58, height: 26)
        page.addSubview(addBtn)

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
        enableToggle.state           = s.enabled           ? .on : .off
        loginToggle.state            = s.launchAtLogin     ? .on : .off
        altTabToggle.state           = s.altTabIntegration ? .on : .off
        windowsShortcutsToggle.state = s.windowsShortcuts  ? .on : .off
        reverseScrollToggle.state    = s.reverseScroll     ? .on : .off
        mouseNavigationToggle.state  = s.mouseNavigation   ? .on : .off
        clipboardHistoryToggle.state = s.clipboardHistory  ? .on : .off
        excludeApps = s.excludedApps
        excludeTable.reloadData()
    }

    @objc private func save() {
        let s = Settings.shared
        s.enabled           = enableToggle.state           == .on
        s.launchAtLogin     = loginToggle.state            == .on
        s.altTabIntegration = altTabToggle.state           == .on
        s.windowsShortcuts  = windowsShortcutsToggle.state == .on
        s.reverseScroll     = reverseScrollToggle.state    == .on
        s.mouseNavigation   = mouseNavigationToggle.state  == .on
        s.clipboardHistory  = clipboardHistoryToggle.state == .on
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
            self.image          = img
            self.imagePosition  = .imageLeft
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
