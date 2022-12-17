//
//  AppDelegate.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import UIKit
import BackgroundTasks
import CoreData

class AppDelegate: NSObject, UIApplicationDelegate {
    var currentTimer: Timer? = nil
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOption: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundId, using: nil) { (task) in
            self.runRefresh(task: task as! BGAppRefreshTask)
        }
        Scheduler.shared.scheduleConfigs()
        return true
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
                if let config = try AppDelegate.checkConfigToRun() {
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
    
    static func checkConfigToRun() throws -> Config? {
        logger.info("checking if anything to refresh")
        let viewContext = PersistenceController.shared.container.viewContext
        let request = NSFetchRequest<Config>(entityName: "Config")
        let results = try viewContext.fetch(request)
        logger.debug("fetched configs \(results)")
        let result = results.sorted {
            a, b in a.nextFireDate < b.nextFireDate
        }.first { config in
            config.url != nil && config.id != nil && config.selector != nil && config.selector?.notBlank() != nil && config.resultType != nil
        }
        logger.debug("next selector is \(result?.name ?? "<nil>")")
        if let r = result, r.nextFireDate < Date() {
            return r
        }
        return nil
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        DownloadManager.shared.updateTasks(completionHandler)
    }
}
