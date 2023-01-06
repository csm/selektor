//
//  Result.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum ResultType: String {
    case Integer = "Integer"
    case Float = "Float"
    case LegacyFloat = "LegacyFloat"
    case Percent = "Percent"
    case LegacyPercent = "LegacyPercent"
    case String = "String"
    case AttributedString = "AttributedString"
    case Image = "Image"
    
    func tag() -> String {
        switch self {
        case .AttributedString: return "S"
        case .Integer: return "i"
        case .Float: return "F"
        case .LegacyFloat: return "f"
        case .Percent: return "%"
        case .LegacyPercent: return "p"
        case .String: return "s"
        case .Image: return "I"
        }
    }
    
    static func from(tag: String?) -> ResultType? {
        if tag == "i" {
            return ResultType.Image
        }
        if tag == "F" {
            return ResultType.Float
        }
        if tag == "f" {
            return ResultType.LegacyFloat
        }
        if tag == "%" {
            return ResultType.Percent
        }
        if tag == "p" {
            return ResultType.LegacyPercent
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
    case FloatResult(float: Decimal)
    case LegacyFloatResult(float: Float)
    case PercentResult(value: Decimal)
    case LegacyPercentResult(value: Float)
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
        case let .LegacyFloatResult(float: f): return "\(f)"
        case let .LegacyPercentResult(value: p): return "\(p * 100)%"
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
            case let .LegacyFloatResult(float: f): return AttributedString("\(f)")
            case let .LegacyPercentResult(value: p): return AttributedString("\(p * 100)%")
            default: return AttributedString("\(self)")
            }
        }
    }
}

extension Result {
    enum CodingKeys: String, CodingKey {
        case IntegerResult = "i"
        case FloatResult = "F"
        case PercentResult = "%"
        case StringResult = "s"
        case ImageResult = "img"
        case AttributedStringResult = "S"
        case LegacyFloatResult = "f"
        case LegacyPercentResult = "p"
    }
}
