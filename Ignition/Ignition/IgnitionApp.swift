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
            // Self-terminate or Hide
            NSApplication.shared.terminate(nil)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .containerBackground(.regularMaterial, for: .window)
                .windowFullScreenBehavior(.disabled)
                .windowMinimizeBehavior(.disabled)
                .windowDismissBehavior(.disabled)
//                .windowResizeBehavior(.disabled)
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
