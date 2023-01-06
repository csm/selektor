//
//  ViewExt.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/3/23.
//

import SwiftUI

extension View {
    private func newWindowInternal(with title: String, level: NSWindow.Level, size: CGSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 20, y: 20, width: size.width, height: size.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.isReleasedWhenClosed = false
        window.title = title
        window.level = level
        window.makeKeyAndOrderFront(nil)
        return window
    }
    
    func openWindow(with title: String = "New Window", level: NSWindow.Level = .normal, size: CGSize = CGSize(width: 400, height: 400)) {
        newWindowInternal(with: title, level: level, size: size).contentView = NSHostingView(rootView: self)
    }
}
