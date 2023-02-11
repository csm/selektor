//
//  AppDelegate.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import UIKit
import BackgroundTasks
import RealmSwift
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    var currentTimer: Timer? = nil
    
    var inForeground: Bool = false
    private var refreshGroup = DispatchGroup()
    
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
            do {
                try await PushManager.shared.updateSchedules()
            } catch {
                logger.error("failed to update schedules: \(error)")
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
        /*
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
         */
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
        do {
            let configs = try PersistenceV2.shared.checkConfigsToRun()
            if !configs.isEmpty {
                for config in configs {
                    if let url = config.url {
                        let id = config.id
                        let name = config.name
                        refreshGroup.enter()
                        queue.addOperation {
                            logger.notice("starting download for config (\(name))")
                            DownloadManager.shared.startDownload(url: url, with: [configIdHeaderKey: id.stringValue], completion: {
                                self.refreshGroup.leave()
                            })
                        }
                    }
                }
                refreshGroup.notify(queue: .main) {
                    completion()
                }
            } else {
                logger.notice("no task to run")
                Scheduler.shared.scheduleConfigs(true)
                completion()
            }
        } catch {
            logger.error("failed to pull refresh \(error)")
            Scheduler.shared.scheduleConfigs(true)
            completion()
        }
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        DownloadManager.shared.updateTasks(completionHandler)
    }
}
