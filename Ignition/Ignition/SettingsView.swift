//
//  SettingsView.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 18.05.26.
//

import SwiftUI

struct SettingsView: View {

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView()
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(SettingsManager())
}
