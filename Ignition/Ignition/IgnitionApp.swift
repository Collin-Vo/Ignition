//
//  IgnitionApp.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 18.04.26.
//

import SwiftUI

@main
struct IgnitionApp: App {

    @State private var settingsManager = SettingsManager()

    init() {
        // Ignition is a launcher: once the user switches to another app, get out of the way.
        // The app's lifetime is the process's, so the observer is never removed.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            NSApplication.shared.hide(nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settingsManager)
                // Without a title bar, dragging the background is the only way to move the window
                .gesture(WindowDragGesture())
                .background {
                    // Liquid Glass fills the window, following its rounded corners
                    ConcentricRectangle()
                        .fill(.clear)
                        .glassEffect(.regular, in: ConcentricRectangle())
                        .ignoresSafeArea()
                }
                .containerBackground(.clear, for: .window)
                .windowFullScreenBehavior(.disabled)
                .windowMinimizeBehavior(.disabled)
                .windowDismissBehavior(.disabled)
                .frame(minWidth: 400, minHeight: 300)
                .onAppear(perform: configureMainWindow)
        }
        .windowLevel(.floating)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
                .environment(settingsManager)
                .frame(width: 500, height: 420)
        }
        .windowLevel(.floating) // Matches the grid window, which would otherwise always cover it
    }

    /// Strips the window down to just its content: no traffic lights and a transparent
    /// title bar, so the content flows to the top while the window stays resizable
    private func configureMainWindow() {
        guard let window = NSApplication.shared.windows.first else { return }
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.resizable)
    }
}
