//
//  OSUnfairLock.swift
//  Selektor
//
//  Created by Casey Marshall on 2/10/23.
//

import Foundation

final class OSUnfairLock {
    private var _lock: UnsafeMutablePointer<os_unfair_lock>
    
    init() {
        _lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        _lock.initialize(to: os_unfair_lock())
    }
    
    deinit {
        _lock.deallocate()
    }
    
    func locked<R>(_ f: () throws -> R) rethrows -> R {
        os_unfair_lock_lock(_lock)
        defer { os_unfair_lock_unlock(_lock) }
        return try f()
    }
}
