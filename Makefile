# PinFolder — build, install, uninstall.
# Everything compiles locally in seconds (Xcode Command Line Tools only),
# so installs are never quarantined by Gatekeeper.

APP      = PinFolder.app
DEST     = /Applications
SERVICES = $(HOME)/Library/Services

all: build

build: PinFolder pinsidebar

PinFolder: PinFolder.swift
	swiftc -O PinFolder.swift -o PinFolder

pinsidebar: pinsidebar.m
	clang -fobjc-arc -O2 -framework Foundation -framework CoreServices pinsidebar.m -o pinsidebar

app: build
	mkdir -p $(APP)/Contents/MacOS
	cp PinFolder pinsidebar $(APP)/Contents/MacOS/
	cp Info.plist $(APP)/Contents/Info.plist

install: app
	-osascript -e 'quit app "PinFolder"' 2>/dev/null
	rm -rf $(DEST)/$(APP)
	cp -R $(APP) $(DEST)/
	python3 make-workflows.py
	/System/Library/CoreServices/pbs -update
	open $(DEST)/$(APP)
	@echo ""
	@echo "Installed. A 📌 appears in the menu bar; right-click any file or folder"
	@echo "in Finder -> Quick Actions for 📌 Pin, 📌 Pin on Top, 📌 Pin to Sidebar."
	@echo "If the Quick Actions don't show up, enable them once in:"
	@echo "  System Settings -> General -> Login Items & Extensions -> Extensions -> Finder"
	@echo "or right-click -> Quick Actions -> Customise..."

uninstall:
	-osascript -e 'quit app "PinFolder"' 2>/dev/null
	rm -rf $(DEST)/$(APP)
	rm -rf "$(SERVICES)/📌 Pin.workflow" "$(SERVICES)/📌 Pin on Top.workflow" "$(SERVICES)/📌 Pin to Sidebar.workflow"
	-/System/Library/CoreServices/pbs -update
	@echo "Uninstalled. Your pins file (~/.pinned-folders), any ' 📌 ' shortcut"
	@echo "symlinks, and sidebar entries are left in place - remove them yourself"
	@echo "if you want them gone."

clean:
	rm -rf PinFolder pinsidebar $(APP)

.PHONY: all build app install uninstall clean
