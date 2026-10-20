//
//  AppListManager.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 10.06.26.
//

import Foundation

@Observable
class SettingsManager {
    let AppLocations = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "Applications", relativeTo: .userDirectory),
        URL(fileURLWithPath: "/System/Volumes/Preboot/Cryptexes/App/System/Applications"),
        URL(fileURLWithPath: "/System/Library/CoreServices/Applications")
    ]

    /// Paths of the apps hidden from the grid, persisted in UserDefaults
    var hiddenApps: [String] = UserDefaults.standard.stringArray(forKey: "hiddenApps") ?? [] {
        didSet {
            UserDefaults.standard.set(hiddenApps, forKey: "hiddenApps")
        }
    }


    func hide(app: AppIdentity) {
        guard !hiddenApps.contains(app.url.path) else { return }
        hiddenApps.append(app.url.path)
    }

    func unhide(paths: Set<String>) {
        hiddenApps.removeAll { paths.contains($0) }
    }
}
