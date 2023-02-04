//
//  SwiftSoupExt.swift
//  Selektor
//
//  Created by Casey Marshall on 1/13/23.
//

import Foundation
import SwiftSoup

extension Element {
    var attributedString: AttributedString {
        get {
            return createAttributedString(html: (try? self.outerHtml()) ?? "")
        }
    }
}
