# FreeSpaceMonitor

A macOS menu bar utility that shows remaining disk space for all mounted volumes and provides quick eject actions.

## Building

```bash
swift build
```

> **Note**
> Building the macOS app on non-macOS platforms will fail because Cocoa is unavailable.

## Creating a Drag-and-Drop Installer DMG

Use the provided packaging script on macOS to build the release binary, wrap it in a `.app` bundle, and generate a drag-and-drop disk image:

```bash
./Scripts/package_dmg.sh
```

The script creates `dist/FreeSpaceMonitor.dmg`, containing the application bundle alongside a shortcut to the system Applications folder. End users can install by dragging the app into Applications.

### Requirements

- macOS with the Xcode command-line tools installed (for `swift` and `hdiutil`)
- Execute the script from the repository root. It will clean and recreate the `dist/` directory.

After running the script, distribute the generated DMG to users. They can open it, then drag **FreeSpaceMonitor.app** onto the **Applications** link to install.
