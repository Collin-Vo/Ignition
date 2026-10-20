//
//  NSImageBakeExtension.swift
//  Ignition
//
//  Created by Collin Voßwinkel on 18.05.26.
//

import Foundation
import SwiftUI

extension NSImage {
    func baked(size: Int) -> NSImage {
        var rect = NSRect(x: 0, y: 0, width: size, height: size)
        
        if let cgImage = self.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            return NSImage(cgImage: cgImage, size: rect.size)
        } else {
            return self
        }
    }
}
