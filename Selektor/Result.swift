//
//  Result.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import UIKit

enum ResultType {
    case Integer
    case Float
    case Percent
    case String
    case Image
    
    func tag() -> String {
        switch self {
        case .Integer: return "i"
        case .Float: return "f"
        case .Percent: return "p"
        case .String: return "s"
        case .Image: return "I"
        }
    }
    
    static func from(tag: String) -> ResultType? {
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
        return nil
    }
}

enum Result : Codable, Equatable {
    case IntegerResult(integer: Int)
    case FloatResult(float: Float)
    case PercentResult(value: Float)
    case StringResult(string: String)
    case ImageResult(imageData: Data)
}

extension Result {
    enum CodingKeys: String, CodingKey {
        case IntegerResult = "i"
        case FloatResult = "f"
        case PercentResult = "p"
        case StringResult = "s"
        case ImageResult = "img"
    }
}
