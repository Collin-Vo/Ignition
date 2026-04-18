//
//  AppGrid.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 18.04.26.
//

import SwiftUI

struct AppGrid: View {
    
    @State private var viewModel: AppGridViewModel = .init(Apps: [])
    let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 110), spacing: 10)
    ]
    
    
    var body: some View {
        ScrollView(){
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(viewModel.Apps, id: \.self) { app in
                    Button(action: {
                        NSWorkspace.shared.open(app)
                    }) {
                        VStack(){
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path)).resizable().frame(width: 64, height: 64)
                            Text(app.lastPathComponent.dropLast(4)).multilineTextAlignment(.center)
                            Spacer()
                        }.frame(width: 110, height: 110)
                        //                        .onTapGesture {
                        //                            NSWorkspace.shared.open(app)
                        //                        }
                    }.buttonStyle(AppLauncherButtonStyle())
                }
            }
        }.padding(.horizontal)
    }
}

struct AppLauncherButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0) // Dimming effect
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0) // Slight "press" effect
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

@Observable
class AppGridViewModel {
    let AppLocations = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "Applications", relativeTo: .userDirectory)
    ]
    var Apps: [URL]
    
    init(Apps: [URL]) {
        
        debugPrint(AppLocations)
        
        let fu = FileUtil()
        
        
        
        self.Apps = fu.getApplications(in: AppLocations)
    }
    
    
}

#Preview {
    AppGrid().frame(width: 700, height: 500)
}
