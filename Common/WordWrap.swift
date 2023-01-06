//
//  WordWrap.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/4/23.
//

import AppKit

func wordWrap(_ text: String, limit: CGFloat, font: NSFont) -> [String] {
    var results: [String] = []
    let words = text.split(separator: /\s+/)
    var currentResult = String()
    for word in words {
        let nextResult: String
        if currentResult.count == 0 {
            nextResult = String(word)
        } else {
            nextResult = currentResult.appending(" ").appending(word)
        }
        let attributedString = NSAttributedString(string: currentResult, attributes: [.font: font])
        let rect = attributedString.boundingRect(with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: font.capHeight))
        print("\"\(currentResult)\" bounds: \(rect)")
        if rect.width >= limit {
            print("insert word break")
            if currentResult.count == 0 {
                print("word break full next result")
                results.append(nextResult)
                currentResult = ""
            } else {
                print("word break before current word")
                results.append(currentResult)
                currentResult = String(word)
            }
        } else {
            currentResult = nextResult
        }
    }
    if currentResult.count > 0 {
        results.append(currentResult)
    }
    return results
}

func pad(array: [String], to length: Int, with value: String) -> [String] {
    var result = array
    while result.count < length {
        result.append(value)
    }
    return result
}

func attributeRanges(
    for array1: [String],
    and array2: [String],
    leftAttributes: [NSAttributedString.Key: Any],
    rightAttributes: [NSAttributedString.Key: Any]
) -> [([NSAttributedString.Key: Any], NSRange)] {
    var results: [([NSAttributedString.Key: Any], NSRange)] = []
    var totalLength = 0
    var isLeft = true
    for element in zip(array1, array2).flatMap({ [$0, $1] }) {
        let attributes: [NSAttributedString.Key: Any]
        if isLeft {
            attributes = leftAttributes
        } else {
            attributes = rightAttributes
        }
        if element.count > 0 {
            results.append((attributes, NSRange(location: totalLength, length: element.count)))
        }
        totalLength = totalLength + element.count + 1
        isLeft = !isLeft
    }
    return results
}
