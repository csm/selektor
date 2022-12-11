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
    var currentTimer: Timer? = nil
    var currentNextFire: Date? = nil
    
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
                print("computed triggerInterval duration: \(duration) seconds")
                let result = (config.lastFetch ?? Date(timeIntervalSince1970: 0)).addingTimeInterval(duration)
                print("computed next fire date for entry \(config): \(result)")
                return result
            }.sorted { (a, b) in
                a < b
            }.first
            if let t = nextFire {
                currentNextFire = max(t, Date().addingTimeInterval(5.0))
                Timer.scheduledTimer(withTimeInterval: currentNextFire?.timeIntervalSinceNow ?? 1.0, repeats: false) { timer in
                    self.currentTimer = timer
                    do {
                        if let config = try AppDelegate.checkConfigToRun() {
                            var request = URLRequest(url: config.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
                            request.allowsCellularAccess = true
                            request.attribution = .user
                            request.setValue(config.id?.uuidString, forHTTPHeaderField: configIdHeaderKey)
                            request.setValue(lynxUserAgent, forHTTPHeaderField: "User-agent")
                            request.setValue("text/html, text/plain, text/sgml, text/css, application/xhtml+xml, */*;q=0.01", forHTTPHeaderField: "Accept")
                            request.setValue("en", forHTTPHeaderField: "Accept-Language")
                            URLSession.shared.downloadTask(with: request) { location, response, error in
                                DownloadManager.shared.handleDownload(config.id!, location, error)
                                currentNextFire = nil
                                currentTimer = nil
                            }.resume()
                        }
                    } catch {
                        print("failed to get current config: \(error)")
                    }
                }
            } else {
                print("nothing to schedule currently")
            }
        } catch {
            print("failed to schedule refresh: \(error)")
        }
    }
    
    func enteringBackground() {
        if let t = currentTimer {
            t.invalidate()
            currentTimer = nil
        }
        if let t = currentNextFire {
            let request = BGAppRefreshTaskRequest(identifier: backgroundId)
            request.earliestBeginDate = max(t, Date().addingTimeInterval(5.0))
            do {
                print("scheduling background refresh at \(request.earliestBeginDate)")
                try BGTaskScheduler.shared.submit(request)
            } catch {
                print("could not schedule background task: \(error)")
            }
        }
    }
}
