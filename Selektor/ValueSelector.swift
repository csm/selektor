//
//  ValueSelector.swift
//  Selektor
//
//  Created by Casey Marshall on 12/1/22.
//

import Foundation
import Kanna

enum ValueSelectorError: Error {
    case HTTPError(statusCode: Int)
    case DecodeIntError(text: String)
    case DecodeFloatError(text: String)
    case DecodePercentError(text: String)
}

class ValueSelector {
    static let shared = ValueSelector()

    let session: URLSession
    
    init() {
        session = URLSession(configuration: URLSessionConfiguration.default)
    }
    
    func fetchValue(url: URL, selector: String, resultIndex: Int, resultType: ResultType, onFetch: @escaping (Result?, Error?) -> Void) {
        print("fetching \(url) with selector \(selector) resultIndex: \(resultIndex)")
        let task = session.dataTask(with: url) { data, response, error in
            print("fetched \(data) \(response) \(error)")
            if let e = error {
                onFetch(nil, e)
            } else if let r = response as? HTTPURLResponse {
                switch r.statusCode {
                case 200:
                    if let d = data, let html = String(data: d, encoding: .utf8) {
                        do {
                            let doc = try HTML(html: html, encoding: .utf8)
                            let path = doc.css(selector, namespaces: nil)
                            if path.count > resultIndex {
                                let value = path[resultIndex]
                                do {
                                    onFetch(try self.decodeResult(node: value, resultType: resultType), nil)
                                } catch {
                                    onFetch(nil, error)
                                }
                            } else {
                                onFetch(nil, nil)
                            }
                        } catch {
                            onFetch(nil, error)
                        }
                    } else {
                        onFetch(nil, nil)
                    }
                default:
                    onFetch(nil, ValueSelectorError.HTTPError(statusCode: r.statusCode))
                }
            }
        }
        task.resume()
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
    
    func decodeResult(node: XMLElement, resultType: ResultType) throws -> Result? {
        let h = node.innerHTML?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch resultType {
        case .Integer:
            if let h = h {
                if let i = Int(h) {
                    print("decoded \(h) as integer \(i)")
                    return Result.IntegerResult(integer: i)
                } else {
                    throw ValueSelectorError.DecodeIntError(text: h)
                }
            }
        case .Float:
            if let h = h {
                if let f = Float(h) {
                    print("decoded \(h) as integer \(f)")
                    return Result.FloatResult(float: f)
                } else {
                    throw ValueSelectorError.DecodeFloatError(text: h)
                }
            }
        case .Percent:
            if let p = try ValueSelector.decodePercent(value: h) {
                print("decoded \(h) as percent \(p)")
                return Result.PercentResult(value: p)
            }
        case .String:
            if let s = node.innerHTML {
                print("decoded string \(s)")
                return Result.StringResult(string: s)
            }
        case .Image:
            print("TODO implement image decoding")
            return nil
        }
        print("failed to decode \(h) as \(resultType)")
        return nil
    }
}
