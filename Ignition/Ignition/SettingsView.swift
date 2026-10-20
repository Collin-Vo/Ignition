//
//  SettingsView.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 18.05.26.
//

import SwiftUI

struct SettingsView: View {
    
    @State private var selectedHiddenApps = Set<AppIdentity.ID>()
    @State var hiddenAppsIdenteties: [AppIdentity] = []
    
    init () {
        let hiddenApps = UserDefaults.standard.stringArray(forKey: "hiddenApps") ?? []
        var loadedIdentities: [AppIdentity] = []
        
        for app in hiddenApps {
            let url = URL(fileURLWithPath: app)
            loadedIdentities.append(AppIdentity(url: url))
        }
        
        // 2. Properly initialize the @State variable from the init
        _hiddenAppsIdenteties = State(initialValue: loadedIdentities)
    }
    
    var body: some View {
        VStack{
            Table(hiddenAppsIdenteties, selection: $selectedHiddenApps){
                TableColumn("App"){ app in
                    HStack{
                        Image(nsImage: app.icon20).resizable().frame(width: 20, height: 20)
                        Text(app.name)
                    }
                }
                TableColumn("Path", value: \.url.relativePath)
            }
            HStack{
                Image(systemName: "plus")
                Divider()
                Image(systemName: "minus").onTapGesture {
                    hiddenAppsIdenteties.removeAll { selectedHiddenApps.contains($0.id) }
                    selectedHiddenApps.removeAll()
                    UserDefaults.standard.set(hiddenAppsIdenteties.map(\.url.path), forKey: "hiddenApps")
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
    }
}

#Preview {
    SettingsView()
}
