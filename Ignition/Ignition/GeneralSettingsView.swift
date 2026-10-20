//
//  GeneralSettingsView.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 20.10.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct GeneralSettingsView: View {

    @Environment(SettingsManager.self) private var settingsManager

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { settingsManager.launchAtLogin },
                    set: { settingsManager.setLaunchAtLogin($0) }
                ))
            }
            Section {
                HiddenAppsList()
            } header: {
                Text("Hidden Apps")
            } footer: {
                Text("Hidden apps don't appear in the grid.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            // The login item may have been changed in System Settings meanwhile
            settingsManager.refreshLaunchAtLogin()
        }
    }
}

struct HiddenAppsList: View {

    @Environment(SettingsManager.self) private var settingsManager
    @State private var selectedHiddenApps = Set<AppIdentity.ID>()
    @State private var hiddenAppsIdentities: [AppIdentity] = []
    @State private var isChoosingAppsToHide = false

    var body: some View {
        VStack(spacing: 0) {
            Table(hiddenAppsIdentities, selection: $selectedHiddenApps){
                TableColumn("App"){ app in
                    HStack{
                        Image(nsImage: app.icon20).resizable().frame(width: 20, height: 20)
                        Text(app.name)
                    }
                }
                TableColumn("Path", value: \.url.path)
            }
            .frame(minHeight: 160)
            HStack{
                Image(systemName: "plus").onTapGesture {
                    isChoosingAppsToHide = true
                }
                Divider()
                Image(systemName: "minus").onTapGesture {
                    let paths = hiddenAppsIdentities
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
        // Presented as a sheet on the settings window, so it can't open behind it
        .fileImporter(isPresented: $isChoosingAppsToHide, allowedContentTypes: [.application], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            for url in urls {
                settingsManager.hide(app: AppIdentity(url: url))
            }
        }
        .fileDialogDefaultDirectory(URL(fileURLWithPath: "/Applications"))
        .fileDialogConfirmationLabel("Hide")
        .onAppear {
            loadIdentities(settingsManager.hiddenApps)
        }
        .onChange(of: settingsManager.hiddenApps) { _, newHiddenApps in
            loadIdentities(newHiddenApps)
        }
    }

    /// Baking icons is expensive, so identities are only rebuilt when the hidden list changes
    private func loadIdentities(_ hiddenApps: [String]) {
        hiddenAppsIdentities = hiddenApps.map { AppIdentity(url: URL(fileURLWithPath: $0)) }
    }
}

#Preview {
    GeneralSettingsView()
        .environment(SettingsManager())
}
