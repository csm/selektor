//
//  AppDelegate.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import UIKit
import BackgroundTasks
import CoreData
//import SwiftMsgPack

class AppDelegate: NSObject, UIApplicationDelegate {
    var currentTimer: Timer? = nil
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOption: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundId, using: nil) { (task) in
            self.runRefresh(task: task as! BGAppRefreshTask)
        }
        Scheduler.shared.scheduleConfigs()
        Task() { await SubscriptionManager.shared.loadSubscriptions() }
        migrateDb()
        return true
    }
    
    func migrateDb() {
        do {
            let viewContext = PersistenceController.shared.container.viewContext
            let request = NSFetchRequest<Config>(entityName: "Config")
            var updated = false
            let configs = try viewContext.fetch(request)
            configs.forEach { config in
                /*if let encoded = config.lastValue {
                    do {
                        let r = try encoded.unpack()
                        logger.debug("decoded \(r)")
                    } catch {
                        logger.error("could not decode \(encoded.base64EncodedString()): \(error)")
                    }
                }*/

                switch (config.result) {
                case .LegacyFloatResult(float: let f):
                    if let d = Decimal(string: "\(f)") {
                        config.result = .FloatResult(float: d)
                    } else {
                        config.result = nil
                    }
                    updated = true
                case .LegacyPercentResult(value: let f):
                    if let d = Decimal(string: "\(f)") {
                        config.result = .PercentResult(value: d)
                    } else {
                        config.result = nil
                    }
                    updated = true
                case nil:
                    config.lastValue = nil
                    updated = true
                default:
                    break
                }
            }
            let historyRequest = NSFetchRequest<History>(entityName: "History")
            let history = try viewContext.fetch(historyRequest)
            history.forEach { history in
                switch (history.result) {
                case .LegacyFloatResult(float: let f):
                    if let d = Decimal(string: "\(f)") {
                        history.result = .FloatResult(float: d)
                    } else {
                        history.result = nil
                    }
                    updated = true
                case .LegacyPercentResult(value: let f):
                    if let d = Decimal(string: "\(f)") {
                        history.result = .PercentResult(value: d)
                    } else {
                        history.result = nil
                    }
                    updated = true
                case nil:
                    history.resultData = nil
                    updated = true
                default:
                    break
                }
            }
            if updated {
                try viewContext.save()
            }
        } catch {
            logger.warning("could not migrate DB: \(error)")
        }
    }
    
    /*func applicationDidEnterBackground(_ application: UIApplication) {
        logger.info("entered background...")
        Scheduler.shared.enteringBackground()
    }*/
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        logger.info("entering foreground...")
        Scheduler.shared.scheduleConfigs()
    }
    
    func runRefresh(task: BGAppRefreshTask) {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.addOperation {
            do {
                if let config = try PersistenceController.checkConfigToRun() {
                    if let id = config.id, let url = config.url {
                        logger.notice("starting download for config (\(config.name))")
                        DownloadManager.shared.startDownload(url: url, with: [configIdHeaderKey: id.uuidString])
                    }
                } else {
                    logger.notice("no task to run")
                    Scheduler.shared.scheduleConfigs(true)
                }
            } catch {
                logger.error("failed to pull refresh \(error)")
                Scheduler.shared.scheduleConfigs(true)
            }
        }
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        DownloadManager.shared.updateTasks(completionHandler)
    }
}
