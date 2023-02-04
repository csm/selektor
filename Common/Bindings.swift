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

extension Binding<Int64> {
    func stringBinding() -> Binding<String> {
        return Binding<String>(get: {
            String(self.wrappedValue)
        }, set: { newValue in
            if let d = Int64(newValue) {
                self.wrappedValue = d
            }
        })
    }
}

extension Binding<Int32> {
    func stringBinding() -> Binding<String> {
        return Binding<String>(get: {
            String(self.wrappedValue)
        }, set: { newValue in
            if let d = Int32(newValue) {
                self.wrappedValue = d
            }
        })
    }
    
    // Create a string binding, but a "one based" binding.
    // That is, when this is 0, string value is "1".
    // When string value is "1", this value is 0.
    func oneBasedStringBinding() -> Binding<String> {
        return Binding<String>(get: {
            String(self.wrappedValue + 1)
        }, set: { newValue in
            if let d = Int32(newValue) {
                if d >= 1 {
                    self.wrappedValue = d - 1
                }
            }
        })
    }
    
    func oneBasedBinding() -> Binding<Int32> {
        return Binding<Int32>(get: {
            self.wrappedValue + 1
        }, set: { newValue in
            if newValue >= 1 {
                self.wrappedValue = newValue - 1
            }
        })
    }
}

extension Binding<String?> {
    func timeUnitBinding() -> Binding<TimeUnit> {
        return Binding<TimeUnit>(get: {
            TimeUnit.forTag(tag: self.wrappedValue)
        }, set: { newValue in
            self.wrappedValue = newValue.tag()
        })
    }
}
