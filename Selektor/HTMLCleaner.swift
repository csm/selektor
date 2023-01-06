//
//  HTMLCleaner.swift
//  Selektor
//
//  Created by Casey Marshall on 12/29/22.
//

import Foundation
import SwiftSoup

func removeScriptTags(element: Element) throws {
    if element.tag().getName() == "script" {
        //logger.info("removing element \(element)")
        try element.remove()
    }
    try element.children().forEach { child in
        try removeScriptTags(element: child)
    }
}

// Remove <script> tags from the given HTML string, returning a new HTML string.
func removeScriptTags(html: String) throws -> String {
    let document = try SwiftSoup.parse(html)
    for child in document.children() {
        try removeScriptTags(element: child)
    }
    return try document.outerHtml()
}
