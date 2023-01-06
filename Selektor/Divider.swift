//
//  Divider.swift
//  Selektor
//
//  Created by Casey Marshall on 12/23/22.
//

import SwiftUI

struct Divider: View {
    let height: CGFloat
    let color: Color
    let opacity: Double
    
    init(height: CGFloat = 1, color: Color = .gray, opacity: Double = 1.0) {
        self.height = height
        self.color = color
        self.opacity = opacity
    }

    var body: some View {
        Group {
            Rectangle()
        }.frame(height: height)
            .foregroundColor(color)
            .opacity(opacity)
    }
}

struct Divider_Previews: PreviewProvider {
    static var previews: some View {
        Divider()
    }
}
