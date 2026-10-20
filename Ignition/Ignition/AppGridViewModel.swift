//
//  AppGridViewModel.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 10.06.26.
//

import Foundation

/// Owns the list of installed apps and the search state for `AppGrid`
@Observable
class AppGridViewModel {

    /// Every folder that is scanned for apps
    let appLocations = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        // The sandbox redirects the home directory to the app container, so resolve the real one
        URL(fileURLWithPath: String(cString: getpwuid(getuid()).pointee.pw_dir)).appendingPathComponent("Applications"),
        // Safari and other apps that ship as Cryptexes
        URL(fileURLWithPath: "/System/Volumes/Preboot/Cryptexes/App/System/Applications"),
        // Directory Utility, Screen Sharing and similar utilities
        URL(fileURLWithPath: "/System/Library/CoreServices/Applications")
    ]

    /// Installed apps, sorted by name, without the hidden ones
    var apps: [AppIdentity] = []
    var searchTerm: String = ""

    /// Paths of the apps to leave out, mirrored from `SettingsManager`
    var hiddenApps: [String]

    /// Folders where apps get installed or removed. The system folders only change with
    /// macOS updates, so they aren't worth watching.
    private var watchedLocations: [URL] {
        appLocations.filter { !$0.path.hasPrefix("/System/") }
    }

    @ObservationIgnored private var folderWatcher: AppFolderWatcher?
    @ObservationIgnored private let fileUtil = FileUtil()

    init(hiddenApps: [String] = []) {
        // Apps are loaded in AppGrid's onAppear: SwiftUI re-runs this initializer on every
        // view update, so it must stay cheap and must never show UI (e.g. an NSOpenPanel)
        self.hiddenApps = hiddenApps
    }

    /// Apps matching the search, case-insensitively. Names that start with the term
    /// come first, then names that only contain it; each group keeps alphabetical order.
    var filteredApps: [AppIdentity] {
        if searchTerm.isEmpty { return apps }

        let term = searchTerm.lowercased()
        var startsWith: [AppIdentity] = []
        var contains: [AppIdentity] = []

        for app in apps {
            let name = app.name.lowercased()
            if name.hasPrefix(term) {
                startsWith.append(app)
            } else if name.contains(term) {
                contains.append(app)
            }
        }
        return startsWith + contains
    }

    /// Rescans all app folders
    func reloadApps() {
        apps = fileUtil.getApplications(in: appLocations).filter { !hiddenApps.contains($0.url.path) }
    }

    /// Applies a changed hidden list. Hiding only filters the loaded apps;
    /// unhiding needs a rescan because those apps were never kept in memory.
    func updateHiddenApps(_ newHiddenApps: [String]) {
        let unhidAny = hiddenApps.contains { !newHiddenApps.contains($0) }
        hiddenApps = newHiddenApps

        if unhidAny {
            reloadApps()
        } else {
            apps.removeAll { newHiddenApps.contains($0.url.path) }
        }
    }

    /// Reloads the apps whenever something changes in the watched app folders
    func startWatchingFolders() {
        if folderWatcher == nil {
            folderWatcher = AppFolderWatcher { [weak self] in
                self?.reloadApps()
            }
        }

        // Watch the URLs we can actually read (granted folders resolve to their bookmark URL)
        folderWatcher?.watch(watchedLocations.compactMap { fileUtil.accessibleURL(for: $0) })
    }

    /// Asks for access to folders the sandbox blocks, reloading the apps after each one is granted
    func requestMissingFolderAccess() async {
        for folder in fileUtil.foldersNeedingAccess(in: appLocations) {
            guard await fileUtil.requestFolderAccess(to: folder) != nil else { continue }
            reloadApps()
            startWatchingFolders()
        }
    }
}
