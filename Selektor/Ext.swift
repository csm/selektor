//
//  Ext.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import SwiftUI

public extension Binding where Value: Equatable {
    init(_ source: Binding<Value?>, replacingNilWith nilProxy: Value) {
        self.init(
            get: { source.wrappedValue ?? nilProxy },
            set: { newValue in
                if newValue == nilProxy { source.wrappedValue = nil }
                else { source.wrappedValue = newValue }
            }
        )
    }
}

public func urlStringBinding(source: Binding<URL?>) -> Binding<String> {
    return Binding(
        get: { source.wrappedValue?.absoluteString ?? "" },
        set: { newValue in
            source.wrappedValue = URL(string: newValue)
        }
    )
}

public func int64StringBinding(source: Binding<Int64>) -> Binding<String> {
    return Binding(
        get: { "\(source.wrappedValue)" },
        set: { newValue in
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
