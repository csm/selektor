//
//  Bindings.swift
//  Selektor
//
//  Created by Casey Marshall on 1/3/23.
//

import SwiftUI

extension Binding {
    func safeBinding<T>(defaultValue: T) -> Binding<T> where Value == Optional<T> {
        return Binding<T>(get: {
            self.wrappedValue ?? defaultValue
        }, set: { newValue in
            self.wrappedValue = newValue
        })
    }
}

extension Binding<URL?> {
    func stringBinding() -> Binding<String> {
        return Binding<String>(get: {
            let s = self.wrappedValue?.absoluteString ?? ""
            if s.hasPrefix("https://") {
                return String(s.dropFirst(8))
            } else if s.hasPrefix("http://") {
                return String(s.dropFirst(7))
            } else {
                return s
            }
        }, set: { newValue in
            self.wrappedValue = URL(string: "https://\(newValue)")
        })
    }
}

extension Binding<String?> {
    func resultTypeBinding() -> Binding<ResultType> {
        return Binding<ResultType>(get: {
            return ResultType.from(tag: self.wrappedValue) ?? ResultType.String
        }, set: { newValue in
            self.wrappedValue = newValue.tag()
        })
    }
}
