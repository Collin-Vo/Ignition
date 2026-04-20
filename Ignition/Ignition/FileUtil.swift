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
    
    func requestFolderAccess(to folderURL: URL) {
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
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
        
        for directory in directories {
            if !hasAccess(to: directory) {
                requestFolderAccess(to: directory)
            }
            
            
            
            guard let enumerator = fileManager.enumerator(at: directory,
                                                          includingPropertiesForKeys: keys,
                                                          options: options) else {
                return []
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
