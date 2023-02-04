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

extension Date {
    static func nextHalfHour(from date: Date = Date()) -> Date {
        let cal = Calendar.current
        let minutes = cal.component(.minute, from: date)
        let seconds = cal.component(.second, from: date)
        let dateSecondsFloored = Calendar.current.date(byAdding: .second, value: -seconds, to: date)!
        if minutes >= 30 {
            return cal.date(
                byAdding: .hour,
                value: 1,
                to: cal.date(
                    byAdding: .minute,
                    value: -minutes,
                    to: dateSecondsFloored
                )!
            )!
        }
        return cal.date(
            byAdding: .minute,
            value: 30 - minutes,
            to: dateSecondsFloored
        )!
    }
}

class Scheduler {
    static let shared = Scheduler()
    var currentTimer: Timer? = nil
    var currentNextFire: Date? = nil
    let dispatchQueue: DispatchQueue
    let operationQueue: OperationQueue
    private lazy var scheduleDebounced: (Bool) -> Void = {
        debounce(interval: 1000, queue: DispatchQueue.main, action: self.doScheduleConfigs(_:))
    }()
    
    private init() {
        dispatchQueue = DispatchQueue(label: "selektor-scheduler", qos: .background)
        operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.underlyingQueue = dispatchQueue
    }

    func scheduleConfigs(_ fromBackground: Bool = false) {
        scheduleDebounced(fromBackground)
    }
    
    var viewContext: NSManagedObjectContext {
        get { PersistenceController.shared.container.viewContext }
    }
    
    private func doScheduleConfigs(_ fromBackground: Bool) {
        do {
            let request = NSFetchRequest<Config>(entityName: "Config")
            let entries = try viewContext.fetch(request)
            let nextFire = entries.sorted {
                a, b in a.nextFireDate < b.nextFireDate
            }.first { config in
                config.url != nil && config.id != nil && config.selector?.notBlank() != nil && config.resultType != nil
            }?.nextFireDate
            logger.info("next fire date is \(nextFire)")
            if let nextFire = nextFire {
                let t = max(nextFire, Date().addingTimeInterval(5.0))
                /*let t = min(
                    // Take the next fire date, or five seconds from now,
                    // if the nextFire date is in the past.
                    max(
                        nextFire,
                        Date().addingTimeInterval(5.0)
                    ),
                    // But also ensure we schedule at least at the nearest half hour
                    Date.nextHalfHour()
                )*/
                logger.debug("computed next fire date \(t)")
                if t != currentNextFire {
                    currentNextFire = t
#if os(iOS)
                    let bgNextFire = min(t, Date.nextHalfHour())
                    // schedule background update
                    BGTaskScheduler.shared.cancelAllTaskRequests()
                    let backgroundRequest = BGAppRefreshTaskRequest(identifier: backgroundId)
                    backgroundRequest.earliestBeginDate = bgNextFire
                    do {
                        try BGTaskScheduler.shared.submit(backgroundRequest)
                        logger.notice("scheduled background refresh at \(backgroundRequest.earliestBeginDate?.description ?? "nil")")
                    } catch {
                        logger.error("could not schedule background task: \(error)")
                    }
#endif
                    if (!fromBackground) {
                        operationQueue.schedule(after: OperationQueue.SchedulerTimeType(t)) {
                            logger.debug("starting foreground download")
                        
                        // and schedule a foreground timer
                        //if let t = currentTimer {
                        //    logger.debug("invalidating current timer \(t)")
                        //    t.invalidate()
                        //}
                        //let nextTimerInterval = max(currentNextFire?.timeIntervalSinceNow ?? 1.0, 1.0)
                        //logger.debug("next timer interval: \(nextTimerInterval)")
                        //let t = Timer(timeInterval: nextTimerInterval, repeats: false) { timer in
                        //DispatchQueue.main.async {
                        //    self.currentTimer = Timer.scheduledTimer(withTimeInterval: nextTimerInterval, repeats: false) { timer in
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
                        //RunLoop.main.add(t, forMode: .default)
                        //self.currentTimer = t
                        //    logger.info("created new timer \(self.currentTimer)")
                        //}
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
