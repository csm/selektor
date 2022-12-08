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
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOption: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundId, using: nil) { (task) in
            self.runRefresh(task: task as! BGAppRefreshTask)
        }
        Scheduler.shared.scheduleConfigs()
        return true
    }
    
    func runRefresh(task: BGAppRefreshTask) {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.addOperation {
            do {
                let viewContext = PersistenceController.shared.container.viewContext
                let request = NSFetchRequest<Config>(entityName: "Config")
                let results = try viewContext.fetch(request)
                let nextConfig = results.sorted { c1, c2 in
                    c1.nextFireDate < c2.nextFireDate
                }.first { config in
                    config.url != nil && config.selector != nil && config.selector?.isEmpty == false && config.resultType != nil
                }
                if let config = nextConfig {
                    if let id = config.id, let url = config.url {
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
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
