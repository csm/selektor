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
    
    func applicationWillResignActive(_ application: UIApplication) {
        Scheduler.shared.enteringBackground()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        Scheduler.shared.scheduleConfigs()
    }
    
    func runRefresh(task: BGAppRefreshTask) {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.addOperation {
            do {
                if let config = try AppDelegate.checkConfigToRun() {
                    if let id = config.id, let url = config.url {
                        print("starting download for config \(config)")
                        DownloadManager.shared.startDownload(url: url, with: [configIdHeaderKey: id.uuidString])
                    }
                } else {
                    print("no task to run")
                }
            } catch {
                print("failed to pull refresh")
            }
        }
    }
    
    static func checkConfigToRun() throws -> Config? {
        print("checking if anything to refresh")
        let viewContext = PersistenceController.shared.container.viewContext
        let request = NSFetchRequest<Config>(entityName: "Config")
        let results = try viewContext.fetch(request)
        print("fetched configs \(results)")
        return results.sorted {
            a, b in a.nextFireDate < b.nextFireDate
        }.first { config in
            config.url != nil && config.id != nil && config.selector != nil && config.selector?.notBlank() != nil && config.resultType != nil
        }
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        _ = DownloadManager.shared
        completionHandler()
    }
}
