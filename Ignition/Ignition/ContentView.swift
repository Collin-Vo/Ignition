//
//  ContentView.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 18.04.26.
//

import SwiftUI

/// Root view of the main window
struct ContentView: View {
    var body: some View {
        AppGrid()
    }
}

#Preview {
    ContentView()
        .environment(SettingsManager())
}
