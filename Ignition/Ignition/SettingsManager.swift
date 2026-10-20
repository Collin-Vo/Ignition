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
    
    var hiddenApps: [String] = [] {
        didSet {
            UserDefaults.standard.set(hiddenApps, forKey: "hiddenApps")
        }
    }

    
    func hide(app: AppIdentity) {
        hiddenApps.append(app.url.relativePath)
        UserDefaults.standard.set(hiddenApps, forKey: "hiddenApps")
    }
}
