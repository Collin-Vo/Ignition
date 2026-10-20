//
//  AppGrid.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 18.04.26.
//

import SwiftUI


struct AppGrid: View {
    
    private enum FocusField: Hashable {
        case search
        case app(URL)
    }

    @FocusState private var focus: FocusField?
    @Environment(SettingsManager.self) private var settingsManager
    @State private var viewModel: AppGridViewModel = .init(hiddenApps: [])
    @State private var columnCount = 1
    
    private let itemWidth: CGFloat = 110
    private let itemSpacing: CGFloat = 10
    private let gridPadding: CGFloat = 16
    
    // Explicit column count so keyboard navigation knows the row layout
    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(itemWidth), spacing: itemSpacing), count: columnCount)
    }

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
                            .font(.largeTitle)
                            .opacity(0)
                        
                        // 2. The visible suggestion suffix
                        Text(ghostTextSuffix)
                            .font(.largeTitle)
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    .lineLimit(1)
                    .allowsHitTesting(false)
                    TextField("Search", text: $viewModel.searchTerm)
                        .focused($focus, equals: .search)
                        .onKeyPress(.downArrow) {
                            guard let first = viewModel.filteredApps.first else { return .ignored }
                            focus = .app(first.url)
                            return .handled
                        }
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
            }.clipped().font(.largeTitle)
                .padding([.horizontal, .top])
                .padding(.bottom, -25)
                .ignoresSafeArea()
                .lineLimit(1)
            Divider().padding(.horizontal)
            ScrollViewReader { proxy in
            ScrollView(){
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(Array(viewModel.filteredApps.enumerated()), id: \.element.id) { index, app in
                        AppButton(app: app, isFocused: focus == .app(app.url))
                            .focusable()
                            .focusEffectDisabled()
                            .focused($focus, equals: .app(app.url))
                            .id(app.url)
                            .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow, .tab, .backTab]) { press in
                                moveFocus(from: index, press: press, proxy: proxy)
                            }
                            .onKeyPress(.return) {
                                NSApplication.shared.hide(nil)
                                NSWorkspace.shared.open(app.url)
                                return .handled
                            }
                            .contextMenu{
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([app.url]);
                                } label: {
                                    Label("Open in Finder", systemImage: "finder").labelStyle(.titleAndIcon)
                                }
                                Button {
                                    settingsManager.hide(app: app)
                                } label: {
                                    Label("Hide App", systemImage: "eye.slash").labelStyle(.titleAndIcon)
                                }
                            }
                    }
                }.padding(.top, 2)
                .padding(.horizontal, gridPadding)
            }
            .onGeometryChange(for: Int.self) { geometry in
                let available = geometry.size.width - gridPadding * 2
                return max(1, Int((available + itemSpacing) / (itemWidth + itemSpacing)))
            } action: { newCount in
                columnCount = newCount
            }
            }
            
            
        }.onAppear {
            
            viewModel.hiddenApps = settingsManager.hiddenApps

            viewModel.apps = viewModel.loadApps(hiddenApps: settingsManager.hiddenApps)
            viewModel.startWatchingFolders()
            
            Task {
                await viewModel.requestMissingFolderAccess()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focus = .search
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
            viewModel.updateHiddenApps(newHiddenApps)

            // The hidden app may have had focus, which would otherwise be lost
            if case .app(let url) = focus, newHiddenApps.contains(url.path) {
                focus = .search
            }
        }
    }
    
    /// Moves focus through the grid row by row (left to right, then the next row).
    private func moveFocus(from index: Int, press: KeyPress, proxy: ScrollViewProxy) -> KeyPress.Result {
        let apps = viewModel.filteredApps
        let lastIndex = apps.count - 1
        let isBackTab = press.key == .backTab || (press.key == .tab && press.modifiers.contains(.shift))
        var target = index
        
        switch press.key {
        case .leftArrow:
            target = index - 1
        case .rightArrow:
            target = index + 1
        case .upArrow:
            target = index - columnCount
        case .downArrow:
            // Jump to the last item if the row below is only partially filled
            if index / columnCount < lastIndex / columnCount {
                target = min(index + columnCount, lastIndex)
            }
        case .tab, .backTab:
            target = isBackTab ? index - 1 : index + 1
            // Let the system move focus out of the grid after the last item
            if target > lastIndex { return .ignored }
        default:
            return .ignored
        }
        
        if target < 0 {
            // Leaving the top of the grid returns to the search field
            if press.key == .upArrow || isBackTab {
                focus = .search
            }
            return .handled
        }
        
        if apps.indices.contains(target) {
            focusApp(apps[target].url, proxy: proxy)
        }
        return .handled
    }
    
    /// Lazy grid items outside the visible area don't exist yet and can't take focus,
    /// so scroll the item into view first and focus it once it has been created.
    private func focusApp(_ url: URL, proxy: ScrollViewProxy) {
        proxy.scrollTo(url)
        DispatchQueue.main.async {
            focus = .app(url)
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

private extension KeyEquivalent {
    /// Shift-Tab is delivered as the backtab character on macOS
    static let backTab = KeyEquivalent("\u{19}")
}

struct AppButton: View {
    let app: AppIdentity
    var isFocused: Bool = false
    
    var body: some View {
        Button(action: {
            NSApplication.shared.hide(nil)
            NSWorkspace.shared.open(app.url)
            
        }) {
            VStack(){
                Image(nsImage: app.icon64).resizable().frame(width: 64, height: 64)
                    .overlay {
                        // Focus indicator around the icon only, replacing the system focus ring
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: 3)
//                            .padding(-3)
                            .opacity(isFocused ? 1 : 0)
                    }
                Text(app.name).multilineTextAlignment(.center)
                Spacer()
            }
        }
        .buttonStyle(AppLauncherButtonStyle())
        // The wrapping view is the focus stop; avoid a second stop for the button itself
        .focusable(false)
    }
}



#Preview {
    AppGrid().frame(width: 700, height: 500)
}
