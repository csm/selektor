//
//  ViewExt.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/3/23.
//

import SwiftUI

private struct WindowEnvironmentKey: EnvironmentKey {
    static let defaultValue: NSWindow? = nil
}

extension EnvironmentValues {
    var window: NSWindow? {
        get { self[WindowEnvironmentKey.self] }
        set { self[WindowEnvironmentKey.self] = newValue }
    }
}

extension View {
    func openWindow(with title: String = "New Window", level: NSWindow.Level = .normal, size: CGSize = CGSize(width: 400, height: 400)) {
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
        window.makeKeyAndOrderFront(self)
        window.makeMain()
        window.makeKey()
        window.contentView = NSHostingView(rootView: self.environment(\.window, window))
    }
}
