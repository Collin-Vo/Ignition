//
//  AppListManager.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 10.06.26.
//

import Foundation
import ServiceManagement

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

    /// Mirrors the login item status. The system owns this state, since the user can also
    /// change it in System Settings, so it is read from SMAppService rather than UserDefaults
    private(set) var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "register" : "unregister") login item: \(error)")
        }
        refreshLaunchAtLogin()
    }

    func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
