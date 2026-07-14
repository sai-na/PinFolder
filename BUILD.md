# PinFolder: Build Instructions

A tiny macOS pinning setup for **folders and files**, built from four pieces:

1. **A menu-bar app** (📌 in the menu bar): lists your pinned items. Click a folder to open it in Finder; click a file to open it in its default app. Pin via a picker, unpin from a submenu.
2. **A Finder Quick Action**: right-click any folder or file → Quick Actions → **📌 Pin**. Adds the item to the menu-bar list.
3. **A second Quick Action**: right-click → **🔝 Pin on Top**. Creates a `📌 <name>` shortcut (symlink) next to the item so it floats to the top of the folder's own Name-sorted list in Finder — the original is never renamed. Run it again to remove the shortcut. (See Step 3.)
4. **A third Quick Action**: right-click → **🗂 Pin to Sidebar**. Toggles the item in the Finder window sidebar (Favourites), powered by the bundled `pinsidebar` helper. (See Step 4.)

Both read and write the same plain-text file: **`~/.pinned-folders`** (one path per line, folders or files). That file is the whole "database". You can edit it by hand any time.

The complete app source is already in this folder: [`PinFolder.swift`](PinFolder.swift). Nothing here needs Xcode, only the command-line tools.

---

## Step 0. Requirements (one-time)

Check the Swift compiler is available:

```bash
swiftc --version
```

If that fails, install the Command Line Tools (takes a few minutes):

```bash
xcode-select --install
```

---

## Step 1. Build the menu-bar app

```bash
cd ~/Documents/GitHub/pinFolder

# compile the menu-bar app and the sidebar helper
swiftc -O PinFolder.swift -o PinFolder
clang -fobjc-arc -O2 -framework Foundation -framework CoreServices pinsidebar.m -o pinsidebar

# make a proper .app bundle so it can be a Login Item
mkdir -p PinFolder.app/Contents/MacOS
cp PinFolder pinsidebar PinFolder.app/Contents/MacOS/

cat > PinFolder.app/Contents/Info.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>PinFolder</string>
    <key>CFBundleIdentifier</key><string>local.sainath.pinfolder</string>
    <key>CFBundleName</key><string>PinFolder</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

# move it to Applications and start it
cp -R PinFolder.app /Applications/
open /Applications/PinFolder.app
```

A 📌 appears in the menu bar. `LSUIElement` = menu-bar only, no Dock icon.

**Start at login is on by default** (registered via `SMAppService` on first launch, macOS 13+). Toggle it in the 📌 menu → **Settings…**, which also has a "Sort pins alphabetically" option.

---

## Step 2. Install the three right-click Quick Actions

A generator script builds the `.workflow` bundles into `build/workflows/`, and the system **Automator Installer** registers them (this is the important part — installing via the system prompt is what registers them as real Quick Actions with `FinderPreview`/`TouchBar` presentation modes, so they appear under right-click → **Quick Actions**, not only buried in the Services submenu):

```bash
cd ~/Documents/GitHub/pinFolder
python3 make-workflows.py
open "build/workflows/📌 Pin.workflow"            # click Install
open "build/workflows/🔝 Pin on Top.workflow"     # click Install
open "build/workflows/🗂 Pin to Sidebar.workflow" # click Install
```

The shell logic lives in [`pin-append.sh`](pin-append.sh) (📌 Pin: add to the menu-bar list), [`pin-on-top.sh`](pin-on-top.sh) (🔝 Pin on Top, see Step 3), and [`pin-sidebar.sh`](pin-sidebar.sh) (Step 4). Edit a script, re-run the generator, and re-open the workflow to update the installed copy.

Right-click any folder or file in Finder → **Quick Actions** (or **Services**) → **📌 Pin**. It appears in the 📌 menu-bar list immediately (the menu re-reads the file every time it opens, so there is nothing to refresh).

If the actions do not show up in the menu, refresh the Services registry and Finder:

```bash
killall pbs; /System/Library/CoreServices/pbs -update; killall Finder
```

They can also be toggled in System Settings → General → Login Items & Extensions → Extensions → **Finder**.

---

## Step 3. The "🔝 Pin on Top" Quick Action (float an item to the top of its folder)

macOS has no real "pin to top of a Finder list" API — Finder always obeys the sort column. The only thing that overrules a **Name** sort is a name, so this action creates a **shortcut**: pinning `conval` makes a symlink `📌 conval → conval` in the same folder, which sorts above everything that starts with a digit or letter. The original folder or file is never renamed, so its path — and everything pointing at it (terminals, IDEs, git remotes, other pins) — keeps working.

It installs with the generator in Step 2. Behaviour details:

- **Toggle:** right-click → Quick Actions → **🔝 Pin on Top** pins; running it again on either the original **or** the `📌` shortcut unpins (deletes only the symlink, never real data).
- **The item appears twice:** the `📌` shortcut at the top, and the original in its normal alphabetical spot. That's the price of not renaming.
- **Only overrules the Name sort, ascending, with groups off.** Sorted by Date/Size, by Name descending, or grouped (View → Use Groups), the shortcut doesn't float.
- **Opens like the real thing:** double-clicking the shortcut opens the actual folder (or the file in its default app).
- **Name collisions are skipped silently:** pinning `dup` when a real item named `📌 dup` exists does nothing.
- **If you move or delete the original,** the shortcut goes stale — just delete it (it's an ordinary symlink).

---

## Step 4. The "🗂 Pin to Sidebar" Quick Action (Finder Favourites)

Right-click any folder or file → Quick Actions → **🗂 Pin to Sidebar** adds it to the sidebar Favourites of every Finder window; run it again to remove it. It installs with the generator in Step 2 and calls the `pinsidebar` helper bundled inside PinFolder.app (source: [`pinsidebar.m`](pinsidebar.m), script: [`pin-sidebar.sh`](pin-sidebar.sh)).

- Uses the deprecated-but-functional `LSSharedFileList` API (the same one the `mysides` tool uses) — if a macOS update ever kills it, the native fallbacks are ⌃⌘T (File → Add to Sidebar) and dragging the folder into the sidebar.
- Sidebar items can also be removed natively: right-click the sidebar entry → **Remove from Sidebar**.
- CLI usage: `pinsidebar list` prints every Favourites path; `pinsidebar toggle <path>…` adds or removes.

---

## How it works (30 seconds)

```
Finder right-click "📌 Pin"  ──appends path──▶  ~/.pinned-folders  ◀──reads on every open── 📌 menu-bar app
```

- One path per line, plain text, folders or files. Edit or clear it by hand any time: `open -e ~/.pinned-folders`
- The app filters out paths that no longer exist, so deleted items disappear from the menu on their own.
- Clicking a pin: folder opens in Finder, file opens in its default app. Each pin shows its real Finder icon, so files and folders are easy to tell apart.
- Unpin from the menu bar (Unpin submenu), or delete the line from the file.

---

## Updating the app

Edit `PinFolder.swift`, then repeat Step 1 (compile, copy into the bundle, copy to /Applications, reopen). Quit the running one first from its menu (Quit PinFolder).

---

## Uninstall

```bash
osascript -e 'quit app "PinFolder"'
rm -rf /Applications/PinFolder.app
rm -f ~/.pinned-folders
rm -rf ~/Library/Services/"📌 Pin.workflow"
rm -rf ~/Library/Services/"🔝 Pin on Top.workflow"
rm -rf ~/Library/Services/"🗂 Pin to Sidebar.workflow"
```

(Any leftover `📌 ` shortcuts are ordinary symlinks — delete them like any file; the originals are untouched. Sidebar entries added with Pin to Sidebar stay until you right-click them → Remove from Sidebar.)

Also remove it from Login Items if you added it there.

---

## Ideas for later (not built)

- Global hotkey to open the pin menu (needs an event tap or a third-party hotkey tool).
- Drag-and-drop a folder or file onto the 📌 icon to pin it.
- "Reveal in Finder" for pinned files (open the enclosing folder with the file selected instead of launching it).
