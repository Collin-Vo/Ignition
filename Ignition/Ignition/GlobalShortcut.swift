//
//  GlobalShortcut.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 21.11.26.
//

import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// The system-wide shortcut that shows or hides Ignition. Users can change it in Settings
    static let toggleIgnition = Self("toggleIgnition", default: .init(.space, modifiers: [.option]))
}

/// The system-wide hotkey. KeyboardShortcuts registers it through Carbon, which works in the
/// App Sandbox and needs no Accessibility permission, and persists the user's choice itself
enum GlobalShortcut {

    /// Starts listening for the shortcut. Changes made in Settings take effect without re-registering
    static func register() {
        KeyboardShortcuts.onKeyUp(for: .toggleIgnition) {
            toggle()
        }
    }

    /// Works like Spotlight: the same shortcut brings Ignition forward and puts it away again
    private static func toggle() {
        let app = NSApplication.shared
        if app.isActive {
            app.hide(nil)
            return
        }
        app.unhide(nil)
        app.activate()
        // Activating clears the search and focuses the field (see AppGrid), so only the
        // grid window has to be brought to the front
        app.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
    }
}
