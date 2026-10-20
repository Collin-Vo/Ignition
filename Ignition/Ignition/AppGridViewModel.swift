//
//  AppGridViewModel.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 10.06.26.
//

import Foundation

@Observable
class AppGridViewModel {
    
    let appLocations = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        // The sandbox redirects the home directory to the app container, so resolve the real one
        URL(fileURLWithPath: String(cString: getpwuid(getuid()).pointee.pw_dir)).appendingPathComponent("Applications"),
        URL(fileURLWithPath: "/System/Volumes/Preboot/Cryptexes/App/System/Applications"),
        URL(fileURLWithPath: "/System/Library/CoreServices/Applications")
    ]
    var apps: [AppIdentity]
    var searchTerm: String = ""
    var focusedApp: URL?
    
    var hiddenApps: [String]
    
    /// Folders where apps get installed or removed. The system folders only change with
    /// macOS updates, so they aren't worth watching.
    private var watchedLocations: [URL] {
        appLocations.filter { !$0.path.hasPrefix("/System/") }
    }
    
    @ObservationIgnored private var folderWatcher: AppFolderWatcher?
    
    init(hiddenApps: [String]) {
        
        // Apps are loaded in AppGrid's onAppear: SwiftUI re-runs this initializer on every
        // view update, so it must stay cheap and must never show UI (e.g. an NSOpenPanel)
        self.hiddenApps = hiddenApps
        self.apps = []
    }
    
    var filteredApps: [AppIdentity] {
        if searchTerm.isEmpty { return apps }
        
        let term = searchTerm.lowercased()
        
        // Bucket 1: Starts with the search term
        let startsWith = apps.filter {
            $0.name.lowercased().hasPrefix(term)
        }
        
        // Bucket 2: Contains the search term but DOES NOT start with it
        let contains = apps.filter {
            $0.name.lowercased().contains(term) &&
            !$0.name.lowercased().hasPrefix(term)
        }
        
        // Combine them: StartsWith gets priority at the top
        return startsWith + contains
    }
    
    
    func loadApps(hiddenApps: [String]) -> [AppIdentity]  {
        let fu = FileUtil()

        apps = fu.getApplications(in: appLocations).filter{!hiddenApps.contains($0.url.path)}

        return apps
    }

    /// Applies a changed hidden list. Hiding only filters the loaded apps;
    /// unhiding needs a rescan because those apps were never kept in memory.
    func updateHiddenApps(_ newHiddenApps: [String]) {
        let unhidAny = hiddenApps.contains { !newHiddenApps.contains($0) }
        hiddenApps = newHiddenApps

        if unhidAny {
            apps = loadApps(hiddenApps: newHiddenApps)
        } else {
            apps.removeAll { newHiddenApps.contains($0.url.path) }
        }
    }
    
    /// Reloads the apps whenever something changes in the watched app folders
    func startWatchingFolders() {
        if folderWatcher == nil {
            folderWatcher = AppFolderWatcher { [weak self] in
                guard let self else { return }
                apps = loadApps(hiddenApps: hiddenApps)
            }
        }
        
        // Watch the URLs we can actually read (granted folders resolve to their bookmark URL)
        let fu = FileUtil()
        folderWatcher?.watch(watchedLocations.compactMap { fu.accessibleURL(for: $0) })
    }
    
    /// Asks for access to folders the sandbox blocks, reloading the apps after each one is granted
    func requestMissingFolderAccess() async {
        let fu = FileUtil()
        
        for folder in fu.foldersNeedingAccess(in: appLocations) {
            guard await fu.requestFolderAccess(to: folder) != nil else { continue }
            apps = loadApps(hiddenApps: hiddenApps)
            startWatchingFolders()
        }
    }
}
