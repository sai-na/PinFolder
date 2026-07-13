// PinFolder - a tiny macOS menu-bar app for pinned folders AND files.
// Pins are stored one path per line in ~/.pinned-folders (plain text),
// shared with the Finder right-click "Pin" Quick Action.
// Clicking a pinned folder opens it in Finder; a pinned file opens in its default app.
// Build: swiftc -O PinFolder.swift -o PinFolder   (see BUILD.md)

import Cocoa
import ServiceManagement

let pinsFile = ("~/.pinned-folders" as NSString).expandingTildeInPath
let sortPinsKey = "sortPinsAlphabetically"
let didSetupLoginKey = "didSetupLoginItem"

func readPins() -> [String] {
    ((try? String(contentsOfFile: pinsFile, encoding: .utf8)) ?? "")
        .split(separator: "\n").map(String.init)
        .filter { !$0.isEmpty && FileManager.default.fileExists(atPath: $0) }
}

func writePins(_ pins: [String]) {
    // trailing newline so shell appends (echo >>) never glue onto the last entry
    let text = pins.isEmpty ? "" : pins.joined(separator: "\n") + "\n"
    try? text.write(toFile: pinsFile, atomically: true, encoding: .utf8)
}

extension NSBox {
    static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow?
    var loginCheckbox: NSButton?
    var sortCheckbox: NSButton?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📌"
        let menu = NSMenu()
        menu.delegate = self          // menu rebuilds itself every time it opens
        statusItem.menu = menu

        // start at login defaults to ON: register once on first launch,
        // after that the Settings toggle is the single source of truth
        if #available(macOS 13.0, *), !UserDefaults.standard.bool(forKey: didSetupLoginKey) {
            try? SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: didSetupLoginKey)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        var pins = readPins()
        if UserDefaults.standard.bool(forKey: sortPinsKey) {
            pins.sort { ($0 as NSString).lastPathComponent
                .localizedStandardCompare(($1 as NSString).lastPathComponent) == .orderedAscending }
        }

        if pins.isEmpty {
            menu.addItem(NSMenuItem(title: "Nothing pinned yet", action: nil, keyEquivalent: ""))
        }
        for path in pins {
            let item = NSMenuItem(title: (path as NSString).lastPathComponent,
                                  action: #selector(openPin(_:)), keyEquivalent: "")
            item.representedObject = path
            item.target = self
            item.toolTip = path
            let icon = NSWorkspace.shared.icon(forFile: path)
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let pick = NSMenuItem(title: "Pin Files or Folders…", action: #selector(pickItems), keyEquivalent: "p")
        pick.target = self
        menu.addItem(pick)

        if !pins.isEmpty {
            let unpinRoot = NSMenuItem(title: "Unpin", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for path in pins {
                let i = NSMenuItem(title: (path as NSString).lastPathComponent,
                                   action: #selector(unpin(_:)), keyEquivalent: "")
                i.representedObject = path
                i.target = self
                sub.addItem(i)
            }
            unpinRoot.submenu = sub
            menu.addItem(unpinRoot)
        }

        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(NSMenuItem(title: "Quit PinFolder",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc func openPin(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @objc func unpin(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        writePins(readPins().filter { $0 != path })
    }

    @objc func openSettings() {
        if settingsWindow == nil { buildSettingsWindow() }
        if #available(macOS 13.0, *) {
            loginCheckbox?.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
        sortCheckbox?.state = UserDefaults.standard.bool(forKey: sortPinsKey) ? .on : .off
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func buildSettingsWindow() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

        let title = NSTextField(labelWithString: "📌 PinFolder")
        title.font = .boldSystemFont(ofSize: 15)
        let ver = NSTextField(labelWithString: "Version \(version)")
        ver.font = .systemFont(ofSize: 11)
        ver.textColor = .secondaryLabelColor

        let login = NSButton(checkboxWithTitle: "Start at login", target: self, action: #selector(toggleLogin(_:)))
        if #available(macOS 13.0, *) {} else { login.isEnabled = false }
        loginCheckbox = login
        let sort = NSButton(checkboxWithTitle: "Sort pins alphabetically", target: self, action: #selector(toggleSort(_:)))
        sortCheckbox = sort

        let github = NSButton(title: "View on GitHub", target: self, action: #selector(openGitHub))
        github.bezelStyle = .rounded

        let stack = NSStackView(views: [title, ver, NSBox.separator(), login, sort, NSBox.separator(), github])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 22, bottom: 20, right: 22)
        stack.setCustomSpacing(2, after: title)
        stack.setCustomSpacing(14, after: ver)

        let win = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        win.title = "PinFolder Settings"
        win.contentView = stack
        win.setContentSize(NSSize(width: 300, height: stack.fittingSize.height))
        win.isReleasedWhenClosed = false
        settingsWindow = win
    }

    @objc func toggleLogin(_ sender: NSButton) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if sender.state == .on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }

    @objc func toggleSort(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: sortPinsKey)
    }

    @objc func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/sai-na/PinFolder")!)
    }

    @objc func pickItems() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Pin"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK {
            var pins = readPins()
            for url in panel.urls where !pins.contains(url.path) {
                pins.append(url.path)
            }
            writePins(pins)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // menu-bar only, no Dock icon
app.run()
