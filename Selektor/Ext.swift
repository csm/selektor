//
//  Ext.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import UIKit
import Kanna

extension String {
    func notBlank() -> String? {
        if self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        return self
    }
}

extension XMLElement {
    var attributedString: AttributedString {
        get {
            let data = self.toHTML?.data(using: .utf8) ?? Data()
            let result = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil)
            return AttributedString(result ?? NSAttributedString(string: self.innerHTML ?? ""))
        }
    }
}
