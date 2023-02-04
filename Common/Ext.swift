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

extension String {
    func notBlank() -> String? {
        if self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        return self
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

extension Int32 {
    func inc() -> Int32 {
        self + 1
    }
}
