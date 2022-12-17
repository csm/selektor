//
//  Logger.swift
//  Selektor
//
//  Created by Casey Marshall on 12/11/22.
//

import Foundation

class CustomLogger {
    enum LogLevel: String {
        case debug = "debug"
        case info = "info"
        case notice = "notice"
        case warning = "warning"
        case error = "error"
    }

    let lock = NSLock()
    let logFile = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appending(path: "selektor.log"))!
    let logFileBackup = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appending(component: "selektor.log.0"))!
    
    func log(level: LogLevel, _ message: String) {
        let m = "\(Date()) [\(level.rawValue)] \(message)"
#if DEBUG
        print(m)
#endif
        guard let data = "\(m)\n".data(using: .utf8) else { return }
        lock.lock()
        do {
            if FileManager.default.fileExists(atPath: logFile.path) {
                let handle = try FileHandle(forWritingTo: logFile)
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try data.write(to: logFile)
            }
            if let size = try FileManager.default.attributesOfItem(atPath: logFile.path)[.size] as? Int {
                if size > 1024 * 1024 {
                    try FileManager.default.removeItem(at: logFileBackup)
                    try FileManager.default.moveItem(at: logFile, to: logFileBackup)
                }
            }
        } catch {
            print("failed to log to \(logFile): \(error)")
        }
        lock.unlock()
    }
    
    func debug(_ message: String) {
        log(level: .debug, message)
    }
    
    func info(_ message: String) {
        log(level: .info, message)
    }
    
    func notice(_ message: String) {
        log(level: .notice, message)
    }
    
    func warning(_ message: String) {
        log(level: .warning, message)
    }
    
    func error(_ message: String) {
        log(level: .error, message)
    }
}

//let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "selektor")
let logger = CustomLogger()
