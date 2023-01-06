//
//  Ext.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import SwiftSoup

extension String {
    func notBlank() -> String? {
        if self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        return self
    }
}

extension Element {
    var attributedString: AttributedString {
        get {
            return createAttributedString(html: (try? self.outerHtml()) ?? "")
        }
    }
}

func createAttributedString(html string: String) -> AttributedString {
    guard let data = string.data(using: .utf8) else {
        return AttributedString(NSAttributedString(string: string))
    }
    guard let result = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil) else {
        return AttributedString(NSAttributedString(string: string))
    }
    return AttributedString(result)
}

