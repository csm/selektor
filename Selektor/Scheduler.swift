//
//  Scheduler.swift
//  Selektor
//
//  Created by Casey Marshall on 12/5/22.
//

import Foundation
import CoreData
import BackgroundTasks

#if os(iOS)
class SimpleTaskRequest : BGAppRefreshTaskRequest {
    init(fireDate: Date?) {
        super.init(identifier: backgroundId)
        self.earliestBeginDate = fireDate
    }
}
#endif

class Scheduler {
    static let shared = Scheduler()
    let context = PersistenceController.shared.container.viewContext
    var currentTimer: Timer? = nil
    var currentNextFire: Date? = nil
    
    func scheduleConfigs(_ fromBackground: Bool = false) {
        do {
            let request = NSFetchRequest<Config>(entityName: "Config")
            let entries = try context.fetch(request)
            let nextFire = entries.sorted {
                a, b in a.nextFireDate < b.nextFireDate
            }.first { config in
                config.url != nil && config.id != nil && config.selector?.notBlank() != nil && config.resultType != nil
            }?.nextFireDate
            logger.info("next fire date is \(nextFire)")
            if let t = nextFire {
                if t != currentNextFire {
                    currentNextFire = max(t, Date().addingTimeInterval(5.0))
#if os(iOS)
                    // schedule background update
                    BGTaskScheduler.shared.cancelAllTaskRequests()
                    let backgroundRequest = BGAppRefreshTaskRequest(identifier: backgroundId)
                    backgroundRequest.earliestBeginDate = currentNextFire
                    do {
                        try BGTaskScheduler.shared.submit(backgroundRequest)
                        logger.notice("scheduled background refresh at \(backgroundRequest.earliestBeginDate?.description ?? "nil")")
                    } catch {
                        logger.error("could not schedule background task: \(error)")
                    }
#endif
                    // and schedule a foreground timer
                    if let t = currentTimer {
                        logger.debug("invalidating current timer \(t)")
                        t.invalidate()
                    }
                    let nextTimerInterval = currentNextFire?.timeIntervalSinceNow ?? 1.0
                    logger.debug("next timer interval: \(nextTimerInterval)")
                    self.currentTimer = Timer.scheduledTimer(withTimeInterval: nextTimerInterval, repeats: false) { timer in
                        do {
                            if let config = try PersistenceController.checkConfigToRun() {
                                DownloadManager.shared.downloadNow(url: config.url!, id: config.id!) {
                                    logger.info("foreground download completed")
                                }
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
                    logger.info("skip scheduling again, \(t) is current next fire date")
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
