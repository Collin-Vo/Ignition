//
//  AppGrid.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 18.04.26.
//

import SwiftUI


struct AppGrid: View {
    
    @FocusState private var isSearchFocused: Bool
    @Environment(SettingsManager.self) private var settingsManager
    @State private var viewModel: AppGridViewModel = .init(hiddenApps: [])
    
    
    let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 110), spacing: 10)
    ]

    private var ghostTextSuffix: String {
        guard !viewModel.searchTerm.isEmpty,
                let firstMatch = viewModel.filteredApps.first?.name else {
            return ""
        }
        
        // Check if the result starts with search term (case-insensitive)
        if firstMatch.lowercased().hasPrefix(viewModel.searchTerm.lowercased()) {
            // Drop the number of characters the user has already typed
            return String(firstMatch.dropFirst(viewModel.searchTerm.count))
        }
        
        return ""
    }
    
    
    var body: some View {
        
        VStack{
            
            HStack(alignment: .lastTextBaseline){
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                ZStack(alignment: .leading){
                    // Ghost Layer
                    HStack(spacing: 0) {
                        // 1. Invisible spacer that exactly matches the user's typed width
                        Text(viewModel.searchTerm)
                            .font(.largeTitle.leading(.tight))
                            .opacity(0)
                        
                        // 2. The visible suggestion suffix
                        Text(ghostTextSuffix)
                            .font(.largeTitle.leading(.tight))
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    .lineLimit(1)
                    .allowsHitTesting(false)
                    TextField("Search", text: $viewModel.searchTerm)
                        .focused($isSearchFocused)
                        .disableAutocorrection(true)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            if let app = viewModel.filteredApps.first {
                                NSApplication.shared.hide(nil)
                                NSWorkspace.shared.open(app.url)
                            }
                        }
                }
                
                
            if !viewModel.searchTerm.isEmpty {
                Image(nsImage: viewModel.filteredApps.first?.icon35 ?? NSImage()).resizable().frame(width: 35, height: 35).padding(.bottom, -8)
            }    else {
                Image(nsImage: viewModel.filteredApps.first?.icon35 ?? NSImage()).resizable().frame(width: 35, height: 35).padding(.bottom, -8).hidden()
            }
            }.clipped().font(.largeTitle.leading(.tight))
                .padding([.horizontal, .top])
                .padding(.bottom, -25)
                .ignoresSafeArea()
                .lineLimit(1)
            Divider().padding(.horizontal)
            ScrollView(){
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(viewModel.filteredApps) { app in
                        AppButton(app: app)
                            .focusable()
                            .onKeyPress(.return) {
                                NSApplication.shared.hide(nil)
                                NSWorkspace.shared.open(app.url)
                                return .handled
                            }
                            .contextMenu {
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([app.url]);
                                } label: {
                                    Label("Open in Finder", systemImage: "folder")
                                }
                                Button {
                                    viewModel.hiddenApps = viewModel.hiddenApps + [app.url.relativePath]
                                } label: {
                                    Label("Hide App", systemImage: "eye.slash")
                                }
                            }
                    }
                }.padding(.horizontal)
            }
            
            
        }.onAppear {
            
            viewModel.hiddenApps = settingsManager.hiddenApps

            viewModel.apps = viewModel.loadApps(hiddenApps: settingsManager.hiddenApps)
            
            Task {
                await viewModel.requestMissingFolderAccess()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
            
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                viewModel.searchTerm = ""
            }
            
        }
        .onChange(of: settingsManager.hiddenApps) { _, newHiddenApps in
            viewModel.hiddenApps = newHiddenApps
            viewModel.apps = viewModel.loadApps(hiddenApps: newHiddenApps)
        }
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

struct AppButton: View {
    let app: AppIdentity
    
    var body: some View {
        Button(action: {
            NSApplication.shared.hide(nil)
            NSWorkspace.shared.open(app.url)
            
        }) {
            VStack(){
                Image(nsImage: app.icon64).resizable().frame(width: 64, height: 64)
                Text(app.name).multilineTextAlignment(.center)
                Spacer()
            }
        }.buttonStyle(AppLauncherButtonStyle())
    }
}



#Preview {
    AppGrid().frame(width: 700, height: 500)
}
