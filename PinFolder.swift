// PinFolder - a tiny macOS menu-bar app for pinned folders AND files.
// Pins are stored one path per line in ~/.pinned-folders (plain text),
// shared with the Finder right-click "Pin" Quick Action.
// Clicking a pinned folder opens it in Finder; a pinned file opens in its default app.
// Build: swiftc -O PinFolder.swift -o PinFolder   (see BUILD.md)

import Cocoa

let pinsFile = ("~/.pinned-folders" as NSString).expandingTildeInPath

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

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📌"
        let menu = NSMenu()
        menu.delegate = self          // menu rebuilds itself every time it opens
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let pins = readPins()

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
