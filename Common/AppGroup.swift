//
//  AppGroup.swift
//  Selektor
//
//  Created by Casey Marshall on 12/10/22.
//

import Foundation

public enum AppGroup: String {
    case main = "group.org.metastatic.selektor.main"
    
    public var containerUrl: URL {
        switch self {
        case .main:
            return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.rawValue)!
        }
    }
}
