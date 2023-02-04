//
//  AppDelegate.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import UIKit
import BackgroundTasks
import CoreData
import UserNotifications
//import SwiftMsgPack

class AppDelegate: NSObject, UIApplicationDelegate {
    var currentTimer: Timer? = nil
    
    var inForeground: Bool = false
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOption: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundId, using: nil) { (task) in
            let task = task as! BGAppRefreshTask
            /*task.expirationHandler = {
                DownloadManager.shared.backgroundDelegateQueue.cancelAllOperations()
            }
            self.runRefresh { task.setTaskCompleted(success: true) }*/
            task.setTaskCompleted(success: true)
        }
        Scheduler.shared.scheduleConfigs()
        inForeground = true
        Task() {
            await SubscriptionManager.shared.loadData()
            do {
                try await CredentialsManager.shared.exchangeCredentials()
            } catch {
                logger.error("failed to exchange credentials: \(error)")
            }
            do {
                if try CredentialsManager.shared.credentials != nil {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch {
                logger.error("could not read credentials: \(error)")
            }
        }
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        migrateDb()
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task() {
            do {
                try await PushManager.shared.registerPushToken(token: deviceToken)
            } catch {
                logger.error("failed to register push token: \(error)")
            }
        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        self.runRefresh {
            completionHandler(.newData)
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        inForeground = false
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        inForeground = true
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
    
    func runRefresh(completion: @escaping () -> Void) {
        let queue = DownloadManager.shared.backgroundDelegateQueue
        queue.addOperation {
            do {
                if let config = try PersistenceController.checkConfigToRun() {
                    if let id = config.id, let url = config.url {
                        logger.notice("starting download for config (\(config.name))")
                        DownloadManager.shared.startDownload(url: url, with: [configIdHeaderKey: id.uuidString], completion: completion)
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
        /*
        queue.operations.last?.completionBlock = {
            task.setTaskCompleted(success: true)
        }
         */
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        DownloadManager.shared.updateTasks(completionHandler)
    }
}
