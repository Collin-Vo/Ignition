# Ignition

Ignition is a fast, keyboard-first app launcher for macOS. It shows every installed app in one floating Liquid Glass window. Type to filter, press Return to launch, and the window gets out of your way.

## Features

### App grid
- **Every app in one place.** Ignition scans these folders and lists the apps alphabetically:
  - `/Applications`
  - `~/Applications`
  - `/System/Applications`
  - `/System/Volumes/Preboot/Cryptexes/App/System/Applications` (Safari and other Cryptex apps)
  - `/System/Library/CoreServices/Applications` (Directory Utility, Screen Sharing, and similar)
- **Responsive layout.** The number of columns follows the window width.
- **Click to launch.** Click any icon to open the app. Ignition hides itself right after.

### Search
- **Instant filtering** as you type, ignoring case.
- **Smart ranking.** Apps whose name *starts with* your search are listed first, then apps that only *contain* it.
- **Inline autocomplete.** The rest of the top match's name appears as ghost text behind what you typed, and its icon appears next to the search field.
- **Return to launch** the top match straight from the search field.
- **Fresh start every time.** The search clears whenever Ignition becomes active again.

### Keyboard navigation
- **↓** in the search field moves focus to the first app.
- **← → ↑ ↓** move through the grid row by row. Moving down from a partly filled row jumps to the last app.
- **Tab / Shift-Tab** step forward and backward through the apps.
- **↑ from the top row** or **Shift-Tab from the first app** goes back to the search field.
- **Return** launches the focused app.
- Ignition scrolls automatically to keep the focused app in view, and draws an accent-colored ring around its icon.

### Context menu
Right-click any app to:
- **Open in Finder**: reveal the app bundle in Finder.
- **Hide App**: remove it from the grid.

### Hiding apps
- Hide apps from the grid's context menu, or from **Settings → General → Hidden Apps**.
- The Hidden Apps table lists every hidden app with its icon and path.
- **+** opens a file picker (starting in `/Applications`, multiple selection allowed) to hide more apps.
- **−** unhides the selected apps, and they come back to the grid right away.
- The hidden list is saved and kept across launches.


### Sandbox-friendly folder access
Ignition runs in the App Sandbox. If one of the app folders can't be read:
- Ignition asks once, with a sheet attached to its window, for access to that folder.
- The grid reloads as soon as you grant access.
- Access is saved as a security-scoped bookmark, so you aren't asked again after relaunching. Stale bookmarks are refreshed automatically, and invalid ones are removed.

## Requirements

- macOS 26.4 or later
- Xcode 26 or later to build from source

## Building

Open the project in Xcode and run the **Ignition** scheme:

```bash
open Ignition/Ignition.xcodeproj
```

## Releasing

`scripts/release.zsh` creates a signed, notarized build for distribution outside the Mac App Store. It:

1. Archives the app in Release configuration and exports it with Developer ID signing.
2. Verifies the signature and the hardened runtime.
3. Notarizes and staples the app, and produces a distributable `.zip`.
4. Builds a signed installer `.pkg` that always installs to `/Applications`, then notarizes and staples it.

One-time setup:

1. Install the **Developer ID Application** and **Developer ID Installer** certificates for the team (Xcode → Settings → Accounts → Manage Certificates).
2. Store notarization credentials in the keychain, using an app-specific password from appleid.apple.com:

   ```bash
   xcrun notarytool store-credentials ignition-notary --apple-id <you@example.com> --team-id JM7U494D23
   ```

Then run:

```bash
scripts/release.zsh
```

Output is written to `.build/release/`: the `.app`, `Ignition-<version>.zip`, `Ignition-<version>.pkg` and the `.xcarchive`. You can override these environment variables:

| Variable         | Default                 | Purpose                              |
| ---------------- | ----------------------- | ------------------------------------ |
| `NOTARY_PROFILE` | `ignition-notary`       | Keychain profile used by `notarytool` |
| `OUTPUT_DIR`     | `<repo>/.build/release` | Where the release artifacts go       |

## Project structure

| File                             | Purpose                                                      |
| -------------------------------- | ------------------------------------------------------------ |
| `IgnitionApp.swift`              | App entry point, window setup, auto-hide, Settings scene     |
| `AppGrid.swift`                  | Search field, ghost-text autocomplete, grid, keyboard navigation, context menu |
| `AppGridViewModel.swift`         | App locations, search ranking, hidden-app filtering, folder access requests |
| `AppIdentity.swift`              | App model: name, URL and pre-rendered icons                  |
| `FileUtil.swift`                 | App discovery, sandbox access checks, security-scoped bookmarks |
| `SettingsManager.swift`          | Hidden apps list and launch-at-login state                   |
| `SettingsView.swift`             | Tabbed Settings window                                       |
| `GeneralSettingsView.swift`      | Launch-at-login toggle and the Hidden Apps table             |
| `NSImageBakeExtension.swift`     | Pre-renders `NSImage` icons at fixed sizes                   |
| `AppStorageExtensions.swift`     | `RawRepresentable` conformance for storing Codable arrays    |
