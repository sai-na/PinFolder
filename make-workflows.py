#!/usr/bin/env python3
"""Generate the three PinFolder Finder Quick Action bundles:

  📌 Pin.workflow            <- pin-append.sh   (add to the menu-bar app's list)
  📌 Pin on Top.workflow     <- pin-on-top.sh   (toggle a sort-first shortcut)
  📌 Pin to Sidebar.workflow <- pin-sidebar.sh  (toggle in Finder Favourites)

Bundles land in ./build/workflows by default (pass a directory to override).
Install them by opening each one — the system Automator Installer registers
them as proper Finder Quick Actions:
  open "build/workflows/📌 Pin.workflow"

Built with plistlib so the shell scripts land in document.wflow correctly
escaped. Re-run after editing any .sh file.
"""
import os
import sys
import plistlib

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "build", "workflows")


def build(menu_name, script_file):
    script = open(os.path.join(HERE, script_file)).read()
    wf = os.path.join(OUTDIR, f"{menu_name}.workflow")

    info = {
        "NSServices": [
            {
                "NSBackgroundColorName": "background",
                "NSIconName": "NSActionTemplate",
                "NSMenuItem": {"default": menu_name},
                "NSMessage": "runWorkflowAsService",
                "NSRequiredContext": {"NSApplicationIdentifier": "com.apple.finder"},
                "NSSendFileTypes": ["public.item"],
            }
        ]
    }

    document = {
        "AMApplicationBuild": "528",
        "AMApplicationVersion": "2.10",
        "AMDocumentVersion": "2",
        "actions": [
            {
                "action": {
                    "AMAccepts": {
                        "Container": "List",
                        "Optional": True,
                        "Types": ["com.apple.cocoa.string"],
                    },
                    "AMActionVersion": "2.0.3",
                    "AMApplication": ["Automator"],
                    "AMParameterProperties": {
                        "COMMAND_STRING": {},
                        "CheckedForUserDefaultShell": {},
                        "inputMethod": {},
                        "shell": {},
                        "source": {},
                    },
                    "AMProvides": {
                        "Container": "List",
                        "Types": ["com.apple.cocoa.string"],
                    },
                    "ActionBundlePath": "/System/Library/Automator/Run Shell Script.action",
                    "ActionName": "Run Shell Script",
                    "ActionParameters": {
                        "COMMAND_STRING": script,
                        "CheckedForUserDefaultShell": True,
                        "inputMethod": 1,  # pass input as arguments
                        "shell": "/bin/zsh",
                        "source": "",
                    },
                    "BundleIdentifier": "com.apple.RunShellScript",
                    "CFBundleVersion": "2.0.3",
                    "CanShowSelectedItemsWhenRun": False,
                    "CanShowWhenRun": True,
                    "Category": ["AMCategoryUtilities"],
                    "Class Name": "RunShellScriptAction",
                    "InputUUID": "B1B2C3D4-0000-0000-0000-000000000001",
                    "Keywords": ["Shell"],
                    "OutputUUID": "B1B2C3D4-0000-0000-0000-000000000002",
                    "UUID": "B1B2C3D4-0000-0000-0000-000000000003",
                    "UnlocalizedApplications": ["Automator"],
                    "arguments": {
                        "0": {"default value": 0, "name": "inputMethod", "required": "0", "type": "0", "uuid": "0"},
                        "1": {"default value": False, "name": "CheckedForUserDefaultShell", "required": "0", "type": "0", "uuid": "1"},
                        "2": {"default value": "", "name": "source", "required": "0", "type": "0", "uuid": "2"},
                        "3": {"default value": "", "name": "COMMAND_STRING", "required": "0", "type": "0", "uuid": "3"},
                        "4": {"default value": "/bin/sh", "name": "shell", "required": "0", "type": "0", "uuid": "4"},
                    },
                    "isViewVisible": 1,
                    "location": "309.000000:305.000000",
                    "nibPath": "/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib",
                },
                "isViewVisible": 1,
            }
        ],
        "connectors": {},
        "workflowMetaData": {
            "applicationBundleIDsByPath": {},
            "applicationPaths": [],
            "inputTypeIdentifier": "com.apple.Automator.fileSystemObject",
            "outputTypeIdentifier": "com.apple.Automator.nothing",
            "presentationMode": 15,
            "processesInput": 0,
            "serviceApplicationBundleID": "com.apple.finder",
            "serviceApplicationPath": "/System/Library/CoreServices/Finder.app",
            "serviceInputTypeIdentifier": "com.apple.Automator.fileSystemObject",
            "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
            "serviceProcessesInput": 0,
            "systemImageName": "NSActionTemplate",
            "useAutomaticInputType": 0,
            "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
        },
    }

    os.makedirs(os.path.join(wf, "Contents"), exist_ok=True)
    with open(os.path.join(wf, "Contents", "Info.plist"), "wb") as fp:
        plistlib.dump(info, fp)
    with open(os.path.join(wf, "Contents", "document.wflow"), "wb") as fp:
        plistlib.dump(document, fp)
    print(wf)


build("📌 Pin", "pin-append.sh")
build("📌 Pin on Top", "pin-on-top.sh")
build("📌 Pin to Sidebar", "pin-sidebar.sh")
