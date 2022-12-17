//
//  Result.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import UIKit

enum ResultType: String {
    case Integer = "Integer"
    case Float = "Float"
    case Percent = "Percent"
    case String = "String"
    case AttributedString = "AttributedString"
    case Image = "Image"
    
    func tag() -> String {
        switch self {
        case .AttributedString: return "S"
        case .Integer: return "i"
        case .Float: return "f"
        case .Percent: return "p"
        case .String: return "s"
        case .Image: return "I"
        }
    }
    
    static func from(tag: String?) -> ResultType? {
        if tag == "i" {
            return ResultType.Image
        }
        if tag == "f" {
            return ResultType.Float
        }
        if tag == "p" {
            return ResultType.Percent
        }
        if tag == "s" {
            return ResultType.String
        }
        if tag == "I" {
            return ResultType.Image
        }
        if tag == "S" {
            return ResultType.AttributedString
        }
        return nil
    }
}

enum Result : Codable, Equatable {
    case IntegerResult(integer: Int)
    case FloatResult(float: Float)
    case PercentResult(value: Float)
    case StringResult(string: String)
    case AttributedStringResult(string: AttributedString)
    case ImageResult(imageData: Data)
    
    func description() -> String {
        switch self {
        case let .StringResult(string: s): return s
        case let .AttributedStringResult(string: s): return String(s.characters)
        case let .IntegerResult(integer: i): return "\(i)"
        case let .FloatResult(float: f): return "\(f)"
        case let .PercentResult(value: p): return "\(p * 100)%"
        default: return "\(self)"
        }
    }

    var attributedString: AttributedString {
        get {
            switch self {
            case let .AttributedStringResult(string: s): return s
            case let .StringResult(string: s): return AttributedString(s)
            case let .IntegerResult(integer: i): return AttributedString("\(i)")
            case let .FloatResult(float: f): return AttributedString("\(f)")
            case let .PercentResult(value: p): return AttributedString("\(p * 100)%")
            default: return AttributedString("\(self)")
            }
        }
    }
}

extension Result {
    enum CodingKeys: String, CodingKey {
        case IntegerResult = "i"
        case FloatResult = "f"
        case PercentResult = "p"
        case StringResult = "s"
        case ImageResult = "img"
        case AttributedStringResult = "S"
    }
}
