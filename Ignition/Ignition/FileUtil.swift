//
//  FileUtil.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 18.04.26.
//

import Foundation
import AppKit

class FileUtil {
    func hasAccess(to folderURL: URL) -> Bool {
        let fileManager = FileManager.default
        
        // Check if the path exists AND if it is readable by this process
        return fileManager.isReadableFile(atPath: folderURL.path)
    }
    
    private static let bookmarksKey = "folderBookmarks"
    
    /// Paths we already called startAccessingSecurityScopedResource on, so we only do it once per launch
    private static var accessedPaths: Set<String> = []
    
    /// Saved bookmarks, keyed by the path of the folder we asked access for
    private var bookmarks: [String: Data] {
        get { UserDefaults.standard.dictionary(forKey: Self.bookmarksKey) as? [String: Data] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: Self.bookmarksKey) }
    }
    
    private func startAccessing(_ url: URL) {
        guard !Self.accessedPaths.contains(url.path) else { return }
        if url.startAccessingSecurityScopedResource() {
            Self.accessedPaths.insert(url.path)
        }
    }
    
    private func saveBookmark(for grantedURL: URL, requestedFolder folderURL: URL) {
        guard let data = try? grantedURL.bookmarkData(options: .withSecurityScope,
                                                      includingResourceValuesForKeys: nil,
                                                      relativeTo: nil) else { return }
        bookmarks[folderURL.path] = data
    }
    
    /// Restores access granted in an earlier launch. Returns nil if there is no usable bookmark.
    func restoreFolderAccess(to folderURL: URL) -> URL? {
        guard let data = bookmarks[folderURL.path] else { return nil }
        
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data,
                                 options: .withSecurityScope,
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &isStale) else {
            bookmarks[folderURL.path] = nil
            return nil
        }
        
        startAccessing(url)
        guard hasAccess(to: url) else {
            bookmarks[folderURL.path] = nil
            return nil
        }
        
        if isStale {
            saveBookmark(for: url, requestedFolder: folderURL)
        }
        return url
    }
    
    /// Returns a readable URL for the folder (restoring a saved bookmark if needed),
    /// or nil if it doesn't exist or the user still has to grant access
    func accessibleURL(for folderURL: URL) -> URL? {
        guard FileManager.default.fileExists(atPath: folderURL.path) else { return nil }
        if hasAccess(to: folderURL) { return folderURL }
        return restoreFolderAccess(to: folderURL)
    }
    
    /// Folders that exist on this Mac but that the sandbox won't let us read yet
    func foldersNeedingAccess(in directories: [URL]) -> [URL] {
        directories.filter {
            FileManager.default.fileExists(atPath: $0.path) && accessibleURL(for: $0) == nil
        }
    }
    
    /// Asks the user to grant access to a folder the sandbox blocks and remembers the choice.
    /// Returns the folder the user picked (with access started), or nil if they cancelled.
    func requestFolderAccess(to folderURL: URL) async -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.message = "Ignition needs access to \(folderURL.path) to show its apps."
        openPanel.prompt = "Grant Access"
        openPanel.directoryURL = folderURL
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        
        NSApp.activate()
        
        // Show the panel as a sheet on our window: the main window is .floating, and a
        // standalone panel ends up behind it, while a sheet always stays attached on top
        let response: NSApplication.ModalResponse
        if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
            response = await withCheckedContinuation { continuation in
                openPanel.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            }
        } else {
            response = openPanel.runModal()
        }
        
        guard response == .OK, let url = openPanel.url else {
            return nil
        }
        
        startAccessing(url)
        saveBookmark(for: url, requestedFolder: folderURL)
        return url
    }
    
    func getApplications(in directories: [URL]) -> [AppIdentity] {
        
        let fileManager = FileManager.default
        var appURLs: [URL] = []
        var apps: [AppIdentity] = []
        
        // Define the keys we want to fetch to make the search faster
        let keys: [URLResourceKey] = [.isApplicationKey, .localizedNameKey]
        
        // Filter options:
        // 1. Skips hidden files like .DS_Store
        // 2. Skips package contents (don't look INSIDE the .app bundle)
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        
        for folder in directories {
            // Skips folders that don't exist or that the user hasn't granted access to yet
            guard let directory = accessibleURL(for: folder) else { continue }
            
            guard let enumerator = fileManager.enumerator(at: directory,
                                                          includingPropertiesForKeys: keys,
                                                          options: options) else {
                continue
            }
            
            
            for case let fileURL as URL in enumerator {
                // Check if the file is actually an application
                if fileURL.pathExtension == "app" {
                    appURLs.append(fileURL)
                }
            }
        }
        
        appURLs.sort(by: { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending })
        
        for url in appURLs {
            apps.append(AppIdentity(url: url))
        }
        
        return apps
    }
}
