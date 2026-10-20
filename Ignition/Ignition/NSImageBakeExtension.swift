//
//  NSImageBakeExtension.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 18.05.26.
//

import AppKit

extension NSImage {
    /// Renders the image once into a plain bitmap of the given point size.
    /// Returns the original image if it can't be rendered.
    func baked(size: Int) -> NSImage {
        var rect = NSRect(x: 0, y: 0, width: size, height: size)
        guard let cgImage = cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return self }
        return NSImage(cgImage: cgImage, size: rect.size)
    }
}
