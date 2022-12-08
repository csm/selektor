//
//  Scheduler.swift
//  Selektor
//
//  Created by Casey Marshall on 12/5/22.
//

import Foundation
import CoreData
import BackgroundTasks

class SimpleTaskRequest : BGAppRefreshTaskRequest {
    init(fireDate: Date?) {
        super.init(identifier: backgroundId)
        self.earliestBeginDate = fireDate
    }
}

class Scheduler {
    static let shared = Scheduler()
    let context = PersistenceController.shared.container.viewContext
    
    func scheduleConfigs() {
        do {
            let request = NSFetchRequest<Config>(entityName: "Config")
            let entries = try context.fetch(request)
            let nextFire = entries.map { config in
                var triggerInterval: Int64
                if config.triggerInterval > 0 {
                    triggerInterval = config.triggerInterval
                } else {
                    triggerInterval = 1
                }
                let triggerIntervalUnits = TimeUnit.forTag(tag: config.triggerIntervalUnits ?? TimeUnit.Days.tag())
                let duration = triggerIntervalUnits.toTimeInterval(timeValue: triggerInterval)
                return (config.lastFetch ?? Date(timeIntervalSince1970: 0)).addingTimeInterval(duration)
            }.sorted { (a, b) in
                a < b
            }.first
            if let t = nextFire {
                let request = SimpleTaskRequest(fireDate: max(t, Date()))
                do {
                    print("scheduling background refresh at \(max(t, Date()))")
                    try BGTaskScheduler.shared.submit(request)
                } catch {
                    print("could not schedule background task: \(error)")
                }
            } else {
                print("nothing to schedule currently")
            }
        } catch {
            print("failed to schedule refresh: \(error)")
        }
    }
}
