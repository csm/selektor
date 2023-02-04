//
//  Debounce.swift
//  Selektor
//
//  Created by Casey Marshall on 1/4/23.
//

import Foundation

func debounce<T>(interval: Int, queue: DispatchQueue, action: @escaping (T) -> Void) -> (T) -> Void {
    var lastFireTime = DispatchTime.now()
    let dispatchDelay = DispatchTimeInterval.milliseconds(interval)
    return { param in
        lastFireTime = DispatchTime.now()
        let dispatchTime = DispatchTime.now() + dispatchDelay
        queue.asyncAfter(deadline: dispatchTime) {
            let when = lastFireTime + dispatchDelay
            let now = DispatchTime.now()
            if now.rawValue >= when.rawValue {
                action(param)
            }
        }
    }
}

func debounce(interval: Int, queue: DispatchQueue, action: @escaping () -> Void) -> () -> Void {
    var lastFireTime = DispatchTime.now()
    let dispatchDelay = DispatchTimeInterval.milliseconds(interval)
    return {
        lastFireTime = DispatchTime.now()
        let dispatchTime = DispatchTime.now() + dispatchDelay
        queue.asyncAfter(deadline: dispatchTime) {
            let when = lastFireTime + dispatchDelay
            let now = DispatchTime.now()
            if now.rawValue >= when.rawValue {
                action()
            }
        }
    }
}
