//
//  Ext.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import SwiftUI
import WebKit

public extension Binding where Value: Equatable {
    init(_ source: Binding<Value?>, replacingNilWith nilProxy: Value) {
        self.init(
            get: {
                print("getting \(source.wrappedValue ?? nilProxy)")
                return source.wrappedValue ?? nilProxy
            },
            set: { newValue in
                print("setting \(newValue)")
                if newValue == nilProxy { source.wrappedValue = nil }
                else { source.wrappedValue = newValue }
            }
        )
    }
}

public func urlStringBinding(source: Binding<URL?>) -> Binding<String> {
    return Binding(
        get: {
            print("getting \(source.wrappedValue?.absoluteString ?? "<empty>")")
            return source.wrappedValue?.absoluteString ?? ""
        },
        set: { newValue in
            print("setting \(URL(string: newValue))")
            source.wrappedValue = URL(string: newValue)
        }
    )
}

public func int64StringBinding(source: Binding<Int64>) -> Binding<String> {
    return Binding(
        get: {
            print("getting \(source.wrappedValue)")
            return "\(source.wrappedValue)"
        },
        set: { newValue in
            print("setting \(Int64(newValue))")
            source.wrappedValue = Int64(newValue) ?? source.wrappedValue
        }
    )
}

func stringTimeUnitBinding(source: Binding<String?>) -> Binding<TimeUnit> {
    return Binding(
        get: {
            if let v = source.wrappedValue {
                return TimeUnit.forTag(tag: v)
            } else {
                return TimeUnit.Seconds
            }
        },
        set: { newValue in
            source.wrappedValue = newValue.tag()
        }
    )
}

extension WKWebView {
    func getElement(selector: String, elementIndex: Int, completionHandler: @escaping (Any, Error) -> Void) {
        self.evaluateJavaScript("document.querySelectorAll(\"\(selector)\")[\(elementIndex)].innerHtml") {
            (result, error) in
            print("got result \(result) error \(error)")
        }
    }
}
