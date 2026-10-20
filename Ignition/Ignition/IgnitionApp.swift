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
                .gesture(
                    WindowDragGesture() // This allows the user to drag the window by its background
                )
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
                .frame(minWidth: 400, minHeight: 300) // Ensure the window is resizable
                .onAppear {
                    if let window = NSApplication.shared.windows.first {
                        // 1. Hide the buttons visually
                        window.standardWindowButton(.closeButton)?.isHidden = true
                        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                        window.standardWindowButton(.zoomButton)?.isHidden = true
                        
                        // 2. Make the titlebar transparent so content flows to the top
                        window.titlebarAppearsTransparent = true
                        window.titleVisibility = .hidden
                        
                        // 3. Ensure it's still resizable
                        window.styleMask.insert(.resizable)
                    }
                }
        }.windowLevel(.floating)
            .windowStyle(.hiddenTitleBar)
        
        Settings{
            SettingsView()
                .environment(settingsManager)
                .frame(width: 500, height: 420)
        }.windowLevel(.floating) // Matches the grid window, which would otherwise always cover it
        
    }
    
    
}



#Preview {
    ContentView()
        .containerBackground(.regularMaterial, for: .window)
        .windowFullScreenBehavior(.disabled)
        .windowMinimizeBehavior(.disabled)
        .windowDismissBehavior(.disabled)
        .windowResizeBehavior(.disabled)
}
