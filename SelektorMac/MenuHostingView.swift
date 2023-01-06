//
//  MenuHostingView.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/4/23.
//

import AppKit
import SwiftUI

class MenuHostingView<Content>: NSHostingView<Content> where Content: View {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
