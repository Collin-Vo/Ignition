//
//  AppIdentity.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 20.04.26.
//

import Foundation
import AppKit

struct AppIdentity: Identifiable {
    let id: UUID = UUID()
    let name: Substring
    let url: URL
    let icon: NSImage
    
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent.dropLast(4)
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
    }
    
}
