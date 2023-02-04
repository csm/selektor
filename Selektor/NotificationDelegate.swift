//
//  NotificationDelegate.swift
//  Selektor
//
//  Created by Casey Marshall on 2/3/23.
//

import Foundation
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        logger.info("got foreground notification: \(notification)")
        return []
    }
}
