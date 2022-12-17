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
    
    func scheduleConfigs(_ fromBackground: Bool = false) {
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
                logger.debug("computed triggerInterval duration: \(duration) seconds")
                let result = (config.lastFetch ?? Date(timeIntervalSince1970: 0)).addingTimeInterval(duration)
                logger.debug("computed next fire date for entry \(config.name): \(result)")
                return result
            }.sorted { (a, b) in
                a < b
            }.first
            logger.info("next fire date is \(nextFire)")
            if let t = nextFire {
                currentNextFire = max(t, Date().addingTimeInterval(5.0))
                // schedule background update
                BGTaskScheduler.shared.cancelAllTaskRequests()
                let backgroundRequest = BGAppRefreshTaskRequest(identifier: backgroundId)
                backgroundRequest.earliestBeginDate = currentNextFire
                do {
                    logger.notice("scheduling background refresh at \(backgroundRequest.earliestBeginDate?.description ?? "nil")")
                    try BGTaskScheduler.shared.submit(backgroundRequest)
                } catch {
                    logger.error("could not schedule background task: \(error)")
                }
                // and schedule a foreground timer
                if let t = currentTimer {
                    t.invalidate()
                }
                self.currentTimer = Timer.scheduledTimer(withTimeInterval: currentNextFire?.timeIntervalSinceNow ?? 1.0, repeats: false) { timer in
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
                                self.currentNextFire = nil
                                self.currentTimer = nil
                                DownloadManager.shared.handleDownload(config.id!, location, error)
                            }.resume()
                        } else {
                            logger.debug("nothing ready to run")
                            self.currentNextFire = nil
                            self.currentTimer = nil
                            self.scheduleConfigs()
                        }
                    } catch {
                        logger.error("failed to get current config: \(error)")
                        self.currentNextFire = nil
                        self.currentTimer = nil
                        self.scheduleConfigs()
                    }
                }
            } else {
                logger.error("nothing to schedule currently")
            }
        } catch {
            logger.error("failed to schedule refresh: \(error)")
        }
    }
    
    func enteringBackground() {
        /*if let t = currentTimer {
            t.invalidate()
            currentTimer = nil
        }
        if let t = currentNextFire {
            logger.info("reschedule next fire in background: \(t)")
            let request = BGAppRefreshTaskRequest(identifier: backgroundId)
            request.earliestBeginDate = max(t, Date().addingTimeInterval(5.0))
            do {
                logger.notice("scheduling background refresh at \(request.earliestBeginDate?.description ?? "nil")")
                try BGTaskScheduler.shared.submit(request)
            } catch {
                logger.error("could not schedule background task: \(error)")
            }
        }*/
    }
}
