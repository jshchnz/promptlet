//
//  DoubleClickableRow.swift
//  Promptlet
//
//  Created by Assistant on 8/30/25.
//

import SwiftUI
import AppKit

struct DoubleClickableRow: NSViewRepresentable {
    let onSingleClick: () -> Void
    let onDoubleClick: () -> Void
    
    func makeNSView(context: Context) -> NSClickableView {
        let view = NSClickableView()
        view.onSingleClick = onSingleClick
        view.onDoubleClick = onDoubleClick
        return view
    }
    
    func updateNSView(_ nsView: NSClickableView, context: Context) {
        nsView.onSingleClick = onSingleClick
        nsView.onDoubleClick = onDoubleClick
    }
}

class NSClickableView: NSView {
    var onSingleClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
        } else if event.clickCount == 1 {
            onSingleClick?()
        }
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}