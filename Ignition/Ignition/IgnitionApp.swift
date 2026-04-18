//
//  IgnitionApp.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 18.04.26.
//

import SwiftUI

@main
struct IgnitionApp: App {
    
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
                .gesture(
                    WindowDragGesture() // This allows the user to drag the window by its background
                )
                .containerBackground(.regularMaterial, for: .window)
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
