import Foundation

class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    var enabled: Bool {
        get { defaults.object(forKey: "enabled") == nil ? true : defaults.bool(forKey: "enabled") }
        set { defaults.set(newValue, forKey: "enabled") }
    }

    var altTabIntegration: Bool {
        get { defaults.bool(forKey: "altTabIntegration") }
        set { defaults.set(newValue, forKey: "altTabIntegration") }
    }

    var excludedApps: [String] {
        get { defaults.stringArray(forKey: "excludedApps") ?? [] }
        set { defaults.set(newValue, forKey: "excludedApps") }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set {
            defaults.set(newValue, forKey: "launchAtLogin")
            setLaunchAtLogin(newValue)
        }
    }

    private func setLaunchAtLogin(_ enable: Bool) {
        let plistPath = NSString(string: "~/Library/LaunchAgents/com.wintab.plist").expandingTildeInPath
        if enable {
            let content = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.wintab</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/WinTab.app/Contents/MacOS/WinTab</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
"""
            try? content.write(toFile: plistPath, atomically: true, encoding: .utf8)
            let _ = Process()
            let task = Process()
            task.launchPath = "/bin/launchctl"
            task.arguments = ["load", plistPath]
            try? task.run()
        } else {
            let task = Process()
            task.launchPath = "/bin/launchctl"
            task.arguments = ["unload", plistPath]
            try? task.run()
            try? FileManager.default.removeItem(atPath: plistPath)
        }
    }
}
