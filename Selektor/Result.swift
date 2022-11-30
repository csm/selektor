//
//  Result.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import UIKit

enum Result : Codable, Equatable {
    case IntegerResult(integer: Int)
    case FloatResult(float: Float)
    case PercentResult(value: Int)
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
