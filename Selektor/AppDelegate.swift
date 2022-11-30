//
//  AppDelegate.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import UIKit
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOption: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "org.metastatic.selektor.refresh", using: nil) { (task) in
            self.runRefresh(task: task as! BGAppRefreshTask)
        }
        return true
    }
    
    func scheduleRefresh() {
        
    }
    
    func runRefresh(task: BGAppRefreshTask) {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        
    }
}
