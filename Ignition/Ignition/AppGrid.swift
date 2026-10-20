//
//  AppGrid.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 18.04.26.
//

import SwiftUI

/// The launcher itself: a search field with inline autocomplete above a keyboard-navigable grid of apps
struct AppGrid: View {

    private enum FocusField: Hashable {
        case search
        case app(URL)
    }

    @FocusState private var focus: FocusField?
    @Environment(SettingsManager.self) private var settingsManager
    @State private var viewModel = AppGridViewModel()
    @State private var columnCount = 1

    private let itemWidth: CGFloat = 110
    private let itemSpacing: CGFloat = 10
    private let gridPadding: CGFloat = 16

    // Explicit column count so keyboard navigation knows the row layout
    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(itemWidth), spacing: itemSpacing), count: columnCount)
    }

    /// The rest of the top match's name, shown as ghost text after what the user typed.
    /// Empty unless the top match starts with the search term.
    private var ghostTextSuffix: String {
        guard !viewModel.searchTerm.isEmpty,
              let firstMatch = viewModel.filteredApps.first?.name,
              firstMatch.lowercased().hasPrefix(viewModel.searchTerm.lowercased()) else {
            return ""
        }
        return String(firstMatch.dropFirst(viewModel.searchTerm.count))
    }

    var body: some View {
        VStack {
            searchBar
            Divider().padding(.horizontal)
            grid
        }
        .onAppear {
            viewModel.hiddenApps = settingsManager.hiddenApps
            viewModel.reloadApps()
            viewModel.startWatchingFolders()

            Task {
                await viewModel.requestMissingFolderAccess()
            }

            // Focusing right away doesn't stick while the window is still being set up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focus = .search
            }
        }
        // Start every activation with an empty search
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.searchTerm = ""
        }
        .onChange(of: settingsManager.hiddenApps) { _, newHiddenApps in
            viewModel.updateHiddenApps(newHiddenApps)

            // The hidden app may have had focus, which would otherwise be lost
            if case .app(let url) = focus, newHiddenApps.contains(url.path) {
                focus = .search
            }
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(alignment: .lastTextBaseline) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)

            ZStack(alignment: .leading) {
                // Ghost text: an invisible copy of the typed text pushes the suggestion
                // suffix to exactly where the typed text ends
                HStack(spacing: 0) {
                    Text(viewModel.searchTerm)
                        .opacity(0)
                    Text(ghostTextSuffix)
                        .foregroundColor(.secondary.opacity(0.3))
                }
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
                        viewModel.filteredApps.first?.launch()
                    }
            }

            // Icon of the top match. Always laid out, so the field doesn't shift when it appears
            Image(nsImage: viewModel.filteredApps.first?.icon35 ?? NSImage())
                .resizable()
                .frame(width: 35, height: 35)
                .padding(.bottom, -8)
                .opacity(viewModel.searchTerm.isEmpty ? 0 : 1)
        }
        .clipped()
        .font(.largeTitle)
        .lineLimit(1)
        .padding([.horizontal, .top])
        .padding(.bottom, -25)
        .ignoresSafeArea()
    }

    // MARK: - Grid

    private var grid: some View {
        ScrollViewReader { proxy in
            ScrollView {
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
                                app.launch()
                                return .handled
                            }
                            .contextMenu {
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([app.url])
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
                }
                .padding(.top, 2)
                .padding(.horizontal, gridPadding)
                // Don't let the fixed-width columns hold the scroll view open, otherwise
                // the measured width below can never shrink and columns never drop
                .frame(minWidth: 0, maxWidth: .infinity)
            }
            // Fit as many fixed-width columns as the window allows
            .onGeometryChange(for: Int.self) { geometry in
                let available = geometry.size.width - gridPadding * 2
                return max(1, Int((available + itemSpacing) / (itemWidth + itemSpacing)))
            } action: { newCount in
                columnCount = newCount
            }
        }
    }

    // MARK: - Keyboard navigation

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

private extension KeyEquivalent {
    /// Shift-Tab is delivered as the backtab character on macOS
    static let backTab = KeyEquivalent("\u{19}")
}

// MARK: - App button

/// A single grid cell: the app's icon and name, launching the app when clicked
struct AppButton: View {
    let app: AppIdentity
    var isFocused: Bool = false

    var body: some View {
        Button(action: app.launch) {
            VStack {
                Image(nsImage: app.icon64)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .overlay {
                        // Focus indicator around the icon only, replacing the system focus ring
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: 3)
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

/// Dims and slightly shrinks the app while it is pressed, instead of the default button chrome
struct AppLauncherButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    AppGrid()
        .environment(SettingsManager())
        .frame(width: 700, height: 500)
}
