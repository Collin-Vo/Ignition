//
//  AppIdentity.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 20.04.26.
//

import AppKit

/// An installed app, with its icon pre-rendered at every size the UI draws it.
struct AppIdentity: Identifiable, Hashable {
    let name: String
    let url: URL
    let icon64: NSImage
    let icon35: NSImage
    let icon20: NSImage

    /// The bundle path is unique and stable across rescans, unlike a generated UUID,
    /// so SwiftUI keeps the same views (and selection) when the app list reloads
    var id: URL { url }

    init(url: URL) {
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent

        // The workspace icon is a lazy multi-representation image that is costly to draw,
        // so it is rendered once per size up front instead of on every grid redraw
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        self.icon64 = icon.baked(size: 64)
        self.icon35 = icon.baked(size: 35)
        self.icon20 = icon.baked(size: 20)
    }

    /// Opens the app and hides Ignition, which has done its job
    func launch() {
        NSApplication.shared.hide(nil)
        NSWorkspace.shared.open(url)
    }

    // Two identities are the same app if they point at the same bundle; the icons don't matter
    static func == (lhs: AppIdentity, rhs: AppIdentity) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
