//
//  ValueSelector.swift
//  Selektor
//
//  Created by Casey Marshall on 12/1/22.
//

import Foundation
import Kanna
import CoreData

enum ValueSelectorError: Error {
    case HTTPError(statusCode: Int)
    case DecodeIntError(text: String)
    case DecodeFloatError(text: String)
    case DecodePercentError(text: String)
    case TimeoutError
    
    var localizedDescription: String {
        switch self {
        case let .HTTPError(statusCode: c): return "Request returned error \(c)"
        case let .DecodeIntError(text: t): return "Could not read \"\(t)\" as an integer."
        case let .DecodeFloatError(text: t): return "Could not read \"\(t)\" as a number."
        case let .DecodePercentError(text: t): return "Could not read \"\(t)\" as a percentage."
        case .TimeoutError: return "The request timed out."
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
        request.setValue(lynxUserAgent, forHTTPHeaderField: "User-agent")
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
                        logger.notice("decoded \(result?.description() ?? "nil")")
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
    
    static func applySelector(location: URL, selector: String, resultIndex: Int, resultType: ResultType) throws -> Result? {
        let doc = try HTML(url: location, encoding: .utf8)
        let path = doc.css(selector, namespaces: nil)
        if path.count > resultIndex {
            let value = path[resultIndex]
            return try decodeResult(node: value, resultType: resultType)
        } else {
            return nil
        }
    }
    
    static func decodePercent(value: String?) throws -> Float? {
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
    
    static func decodeResult(node: XMLElement, resultType: ResultType) throws -> Result? {
        let h = node.innerHTML?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch resultType {
        case .Integer:
            if let h = h {
                if let i = Int(h) {
                    logger.debug("decoded \(h) as integer \(i)")
                    return Result.IntegerResult(integer: i)
                } else {
                    throw ValueSelectorError.DecodeIntError(text: h)
                }
            }
        case .Float:
            if let h = h {
                if let f = Float(h) {
                    logger.debug("decoded \(h) as integer \(f)")
                    return Result.FloatResult(float: f)
                } else {
                    throw ValueSelectorError.DecodeFloatError(text: h)
                }
            }
        case .Percent:
            if let p = try ValueSelector.decodePercent(value: h) {
                logger.debug("decoded \(h?.description ?? "nil") as percent \(p)")
                return Result.PercentResult(value: p)
            }
        case .String:
            if let s = node.innerHTML {
                print("decoded string \(s)")
                return Result.StringResult(string: s)
            }
        case .AttributedString:
            return Result.AttributedStringResult(string: node.attributedString)
        case .Image:
            print("TODO implement image decoding")
            return nil
        }
        logger.debug("failed to decode \(h?.description ?? "nil") as \(resultType.rawValue)")
        return nil
    }
}
