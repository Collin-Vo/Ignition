//
//  SettingsView.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 18.05.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {

    @Environment(SettingsManager.self) private var settingsManager
    @State private var selectedHiddenApps = Set<AppIdentity.ID>()
    @State var hiddenAppsIdenteties: [AppIdentity] = []

    var body: some View {
        VStack{
            Table(hiddenAppsIdenteties, selection: $selectedHiddenApps){
                TableColumn("App"){ app in
                    HStack{
                        Image(nsImage: app.icon20).resizable().frame(width: 20, height: 20)
                        Text(app.name)
                    }
                }
                TableColumn("Path", value: \.url.path)
            }
            HStack{
                Image(systemName: "plus").onTapGesture {
                    chooseAppsToHide()
                }
                Divider()
                Image(systemName: "minus").onTapGesture {
                    let paths = hiddenAppsIdenteties
                        .filter { selectedHiddenApps.contains($0.id) }
                        .map(\.url.path)
                    selectedHiddenApps.removeAll()
                    settingsManager.unhide(paths: Set(paths))
                }
                Spacer()
            }.frame(height: 20)
            .foregroundStyle(.secondary)
            .font(.system(size: 11))
            .fontWeight(.semibold)
            .padding(.leading, 7)
            .padding(.vertical, 2)
            .background{

                Rectangle().fill(.quinary).stroke(.separator, style: .init(lineWidth: 1))

            }
        }
        .onAppear {
            loadIdentities(settingsManager.hiddenApps)
        }
        .onChange(of: settingsManager.hiddenApps) { _, newHiddenApps in
            loadIdentities(newHiddenApps)
        }
    }

    /// Baking icons is expensive, so identities are only rebuilt when the hidden list changes
    private func loadIdentities(_ hiddenApps: [String]) {
        hiddenAppsIdenteties = hiddenApps.map { AppIdentity(url: URL(fileURLWithPath: $0)) }
    }

    private func chooseAppsToHide() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Hide"

        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            settingsManager.hide(app: AppIdentity(url: url))
        }
    }
}

#Preview {
    SettingsView()
        .environment(SettingsManager())
}
