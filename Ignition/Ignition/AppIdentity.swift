//
//  AppIdentity.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 20.04.26.
//

import Foundation
import AppKit

struct AppIdentity: Identifiable, Hashable {
    let id: UUID = UUID()
    let name: String
    let url: URL
    let iconProxy: NSImage
    let icon64: NSImage
    let icon35: NSImage
    let icon20: NSImage

    
    init(url: URL) {
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.iconProxy = NSWorkspace.shared.icon(forFile: url.path)
        self.icon64 = self.iconProxy.baked(size: 64)
        self.icon35 = self.iconProxy.baked(size: 35)
        self.icon20 = self.iconProxy.baked(size: 20)
    }
    
    func bakeIcon(icon: NSImage, size: Int) -> NSImage {
        var rect = NSRect(x: 0, y: 0, width: size, height: size)
        
        if let cgImage = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            // Re-wrap it in a clean, static NSImage
            return NSImage(cgImage: cgImage, size: rect.size)
        } else {
            // Fallback just in case
            return icon
        }
    }
    
}
