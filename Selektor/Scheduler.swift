//
//  Scheduler.swift
//  Selektor
//
//  Created by Casey Marshall on 12/5/22.
//

import Foundation
import RealmSwift
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
    
    private func doScheduleConfigs(_ fromBackground: Bool) {
        let now = Date()
        guard let realm = try? PersistenceV2.shared.realm else {
            logger.error("could not get realm")
            return
        }
        let entries = realm.objects(ConfigV2.self)
        logger.debug("fetched entries: \(entries)")
        let nextFire = entries
            .sorted(by: { a, b in a.nextFireDate < b.nextFireDate })
            .filter { config in
                config.url != nil && config.selector.notBlank() != nil
            }
            .first?
            .nextFireDate
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
                /*
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
                 */
#endif
                if (!fromBackground) {
                    operationQueue.schedule(after: OperationQueue.SchedulerTimeType(t)) {
                        logger.debug("starting foreground download")
                        let configs = (try? PersistenceV2.shared.checkConfigsToRun()) ?? []
                        if configs.isEmpty {
                            logger.debug("nothing ready to run")
                            self.currentNextFire = nil
                            self.currentTimer = nil
                            self.scheduleConfigs()
                        } else {
                            let configData = configs.map { config in
                                (config.url!, config.id, config.selector, config.elementIndex, config.resultType)
                            }
                            Task(priority: .background) {
                                for (url, id, _, _, _) in configData {
/*#if os(macOS)
 FIXME, Erik is fuckin broke
                                    do {
                                        let result = try await ErikValueSelector.applySelector(url: url, selector: selector, elementIndex: elementIndex, resultType: resultType)
                                        PersistenceV2.shared.handleResult(id: id, result: result, error: nil)
                                    } catch {
                                        PersistenceV2.shared.handleResult(id: id, result: nil, error: error)
                                    }
#else*/
                                    await DownloadManager.shared.downloadNow(url: url, id: id)
/*#endif*/
                                }
                                self.currentNextFire = nil
                                self.currentTimer = nil
                                self.scheduleConfigs()
                            }
                        }
                    }
                }
            } else {
                logger.info("skip scheduling again, \(t) is current next fire date")
            }
        } else {
            logger.error("nothing to schedule currently")
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
