//
//  ValueSelector.swift
//  Selektor
//
//  Created by Casey Marshall on 12/1/22.
//

import Foundation
import CoreData
import SwiftSoup

enum ValueSelectorError: Error {
    case HTTPError(statusCode: Int)
    case DecodeIntError(text: String)
    case DecodeFloatError(text: String)
    case DecodePercentError(text: String)
    case TimeoutError
    case UnknownError
    case BadInputError
    
    var localizedDescription: String {
        switch self {
        case let .HTTPError(statusCode: c): return "Request returned error \(c)"
        case let .DecodeIntError(text: t): return "Could not read \"\(t)\" as an integer."
        case let .DecodeFloatError(text: t): return "Could not read \"\(t)\" as a number."
        case let .DecodePercentError(text: t): return "Could not read \"\(t)\" as a percentage."
        case .TimeoutError: return "The request timed out."
        case .UnknownError: return "The URL could not be fetched."
        case .BadInputError: return "The web page could not be read."
        }
    }
}

protocol ValueSelectorDelegate {
    func fetch(withId: UUID, didCompleteWithResult: Result?)
    func fetch(withId: UUID, didFailWithError: Error)
}

class ValueSelector {
    static let shared = ValueSelector()
    let session: URLSession
    
    init() {
        session = URLSession(configuration: .default)
    }
    
    func fetchValue(url: URL, selector: String, resultIndex: Int, resultType: ResultType, onComplete: @escaping (Result?, Error?) -> Void) {
        logger.info("fetching \(url) with selector \(selector) resultIndex: \(resultIndex) resultType: \(resultType.rawValue)")
        var request = URLRequest(url: url, timeoutInterval: 20.0)
        request.setValue(safariUserAgent, forHTTPHeaderField: "User-agent")
        request.setValue("text/html, text/plain, text/sgml, text/css, application/xhtml+xml, */*;q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("en", forHTTPHeaderField: "Accept-Language")
        let task = session.downloadTask(with: request) { location, response, error in
            if error != nil {
                logger.error("fetch returned error: \(error!)")
                onComplete(nil, error)
            } else if let resp = response as? HTTPURLResponse, let u = location {
                switch resp.statusCode {
                case 200:
                    do {
                        logger.notice("read data into URL: \(u)")
                        let result = try ValueSelector.applySelector(location: u, selector: selector, resultIndex: resultIndex, resultType: resultType)
                        logger.notice("decoded \(result?.formatted() ?? "nil")")
                        onComplete(result, nil)
                    } catch {
                        logger.error("error decoding \(error)")
                        onComplete(nil, error)
                    }
                default:
                    onComplete(nil, ValueSelectorError.HTTPError(statusCode: resp.statusCode))
                }
            } else {
                logger.error("not an HTTP response? no url? \(response) \(location?.description ?? "nil")")
                onComplete(nil, nil)
            }
        }
        task.resume()
    }

    static func applySelector(location: URL, selector: String, resultIndex: Int, resultType: ResultType, documentEncoding: String.Encoding = .utf8) throws -> Result? {
        guard let htmlData = String(data: try Data(contentsOf: location), encoding: documentEncoding) else {
            throw ValueSelectorError.BadInputError
        }
        let html = try removeScriptTags(html: htmlData)
        let doc = try SwiftSoup.parse(html)
        let elements = try doc.select(selector)
        if elements.count <= resultIndex {
            return nil
        } else {
            let element = elements[resultIndex]
            return try decodeResult(element: element, resultType: resultType)
        }
    }
    
    static func decodePercent(value: String?) throws -> Decimal? {
        if var v = value {
            if v.hasSuffix("%") {
                v = String(v.dropLast(1))
            }
            if let p = Decimal(string: v) {
                return p / 100
            }
        }
        throw ValueSelectorError.DecodePercentError(text: value ?? "")
    }
    
    static func decodeLegacyPercent(value: String?) throws -> Float? {
        if var v = value {
            if v.hasSuffix("%") {
                v = String(v.dropLast(1))
            }
            if let p = Float(v) {
                return p / 100
            }
        }
        throw ValueSelectorError.DecodePercentError(text: value ?? "")
    }
    
    static func decodeResult(element: Element, resultType: ResultType) throws -> Result? {
        let h = try element.html().trimmingCharacters(in: .whitespacesAndNewlines)
        switch resultType {
        case .Integer:
            if let i = Int(h) {
                logger.debug("decoded \(h) as integer \(i)")
                return Result.IntegerResult(integer: i)
            } else {
                throw ValueSelectorError.DecodeIntError(text: h)
            }
        case .Float:
            if let f = Decimal(string: h) {
                logger.debug("decoded \(h) as float \(f)")
                return Result.FloatResult(float: f)
            } else {
                throw ValueSelectorError.DecodeFloatError(text: h)
            }
        case .LegacyFloat:
            if let f = Float(h) {
                logger.debug("decoded \(h) as float \(f)")
                return Result.LegacyFloatResult(float: f)
            } else {
                throw ValueSelectorError.DecodeFloatError(text: h)
            }
        case .Percent:
            if let p = try ValueSelector.decodePercent(value: h) {
                logger.debug("decoded \(h) as percent \(p)")
                return Result.PercentResult(value: p)
            }
        case .LegacyPercent:
            if let p = try ValueSelector.decodeLegacyPercent(value: h) {
                return Result.LegacyPercentResult(value: p)
            }
        case .String:
            let s = String(element.attributedString.characters)
            print("decoded string \(s)")
            return Result.StringResult(string: s)
        case .AttributedString:
            return Result.AttributedStringResult(string: element.attributedString)
        case .Image:
            print("TODO implement image decoding")
            return nil
        }
        logger.debug("failed to decode \(h) as \(resultType.rawValue)")
        return nil
    }
    
    static func decodeResult(text: String, resultType: ResultType) throws -> Result? {
        switch resultType {
        case .Integer:
            if let h = text.notBlank() {
                if let i = Int(h) {
                    logger.debug("decoded \(h) as integer \(i)")
                    return Result.IntegerResult(integer: i)
                } else {
                    throw ValueSelectorError.DecodeIntError(text: h)
                }
            }
        case .Float:
            if let h = text.notBlank() {
                if let f = Decimal(string: h) {
                    logger.debug("decoded \(h) as decimal \(f)")
                    return Result.FloatResult(float: f)
                } else {
                    throw ValueSelectorError.DecodeFloatError(text: h)
                }
            }
        case .LegacyFloat:
            if let h = text.notBlank() {
                if let f = Float(h) {
                    return Result.LegacyFloatResult(float: f)
                } else {
                    throw ValueSelectorError.DecodeFloatError(text: h)
                }
            }
        case .Percent:
            if let p = try ValueSelector.decodePercent(value: text.notBlank()) {
                logger.debug("decoded \(text) as percent \(p)")
                return Result.PercentResult(value: p)
            }
        case .LegacyPercent:
            if let p = try ValueSelector.decodeLegacyPercent(value: text.notBlank()) {
                return Result.LegacyPercentResult(value: p)
            }
        case .String:
            if let str = text.notBlank() {
                let s = String(createAttributedString(html: str).characters)
                print("decoded string \(s)")
                return Result.StringResult(string: s)
            }
        case .AttributedString:
            return Result.AttributedStringResult(string: AttributedString(stringLiteral: text))
        case .Image:
            print("TODO implement image decoding")
            return nil
        }
        return nil
    }
}
