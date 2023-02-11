//
//  DownloadManager.swift
//  Selektor
//
//  Created by Casey Marshall on 12/6/22.
//

import Foundation
import CoreData
import UserNotifications
import RealmSwift

#if os(iOS)
import WatchConnectivity
#endif

class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    
    var backgroundSession: URLSession? = nil
    var foregroundSession: URLSession? = nil
    @Published var tasks: [URLSessionTask] = []
    @Published var completedTasks: [(URLSessionTask, URL?, Error?)] = []
    var backgroundCompletion: (() -> Void)? = nil
    
    #if os(iOS)
    private var watchDelegate: WCSessionDelegate? = nil
    #endif

    override private init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: backgroundId)
        config.isDiscretionary = false
        config.allowsCellularAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.httpCookieStorage = nil
        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: delegateQueue)
        let fgConfig = URLSessionConfiguration.default
        config.isDiscretionary = false
        config.allowsCellularAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.httpCookieStorage = nil
        foregroundSession = URLSession(configuration: fgConfig)
        updateTasks()
    }
    
    var backgroundDelegateQueue: OperationQueue {
        get {
            backgroundSession!.delegateQueue
        }
    }
    
    func startDownload(url: URL, with headers: Dictionary<String, String> = [:], completion: @escaping () -> Void) {
        self.backgroundCompletion = completion
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.attribution = .user
        headers.forEach { (k, v) in
            request.setValue(v, forHTTPHeaderField: k)
        }
        request.setValue(safariUserAgent, forHTTPHeaderField: "User-agent")
        request.setValue("text/html, text/plain, text/sgml, text/css, application/xhtml+xml, */*;q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("en", forHTTPHeaderField: "Accept-Language")
        let task = backgroundSession!.downloadTask(with: request)
        task.resume()
        tasks.append(task)
    }
    
    func downloadNow(url: URL, id: ObjectId, with headers: Dictionary<String, String> = [:], decodeDownload: Bool = true) async {
        await withUnsafeContinuation { cont in
            downloadNow(url: url, id: id, with: headers) {
                cont.resume()
            }
        }
    }
    
    func downloadNow(url: URL, id: ObjectId, with headers: Dictionary<String, String> = [:], decodeDownload: Bool = true, completionHandler: @escaping () -> Void) {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.attribution = .user
        headers.forEach { (k, v) in
            request.setValue(v, forHTTPHeaderField: k)
        }
        request.setValue(safariUserAgent, forHTTPHeaderField: "User-agent")
        request.setValue("text/html, text/plain, text/sgml, text/css, application/xhtml+xml, */*;q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("en", forHTTPHeaderField: "Accept-Language")
        let task = foregroundSession!.downloadTask(with: request) { location, response, error in
            if (decodeDownload) {
                if let e = error {
                    self.handleDownload(response, id, nil, e)
                } else {
                    if let r = response as? HTTPURLResponse {
                        switch r.statusCode {
                        case 200: self.handleDownload(r, id, location, nil)
                        default: self.handleDownload(r, id, nil, ValueSelectorError.HTTPError(statusCode: r.statusCode))
                        }
                    } else {
                        self.handleDownload(response, id, nil, ValueSelectorError.UnknownError)
                    }
                }
            }
            completionHandler()
        }
        task.resume()
    }
    
    func updateTasks(_ completionHandler: (() -> Void)? = nil) {
        backgroundSession?.getAllTasks { tasks in
            DispatchQueue.main.async {
                self.tasks = tasks
                if let completionHandler = completionHandler {
                    completionHandler()
                }
            }
        }
    }
}

extension DownloadManager : URLSessionDelegate, URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        logger.info("urlSession \(session) didCreateTask: \(task)")
    }

    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        logger.info("urlSession \(session) taskIsWaitingForConnectivity: \(task)")
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        logger.debug("urlSession \(session) downloadTask: \(downloadTask) didFinishDownloadingTo: \(location)")
        if let request = downloadTask.currentRequest, let idStr = request.value(forHTTPHeaderField: configIdHeaderKey), let id = try? ObjectId(string: idStr), let response = downloadTask.response {
            self.handleDownload(response, id, location, nil, true)
        } else {
            logger.info("no UUID header or bad one: \(downloadTask.currentRequest?.value(forHTTPHeaderField: configIdHeaderKey))")
        }
        if let c = backgroundCompletion {
            c()
            backgroundCompletion = nil
        }
        self.updateTasks()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        logger.debug("urlSession \(session) task: \(task) didCompleteWithError: \(error)")
        self.tasks = self.tasks.filter { t in t != task }
        if let error = error {
            if let idStr = task.currentRequest?.value(forHTTPHeaderField: configIdHeaderKey), let id = try? ObjectId(string: idStr), let response = task.response {
                self.handleDownload(response, id, nil, error, true)
            } else {
                logger.info("no UUID header or bad one: \(task.currentRequest?.value(forHTTPHeaderField: configIdHeaderKey))")
                if let c = backgroundCompletion {
                    c()
                    backgroundCompletion = nil
                }
            }
            if let c = backgroundCompletion {
                c()
                backgroundSession = nil
            }
            self.updateTasks()
        }
    }
}

#if os(iOS)
class DownloadManagerWatchDelegate : NSObject, WCSessionDelegate {
    let result: Result
    let config: ConfigV2
    
    init(result: Result, config: ConfigV2) {
        self.result = result
        self.config = config
        super.init()
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        switch activationState {
        case .activated:
            if session.isPaired {
                if let lastFetch = config.lastFetch {
                    let payload: [String: Any] = [
                        WatchPayloadKey.configId.rawValue: config.id.stringValue,
                        WatchPayloadKey.configName.rawValue: config.name,
                        WatchPayloadKey.resultString.rawValue: result.formatted(),
                        WatchPayloadKey.updatedDate.rawValue: lastFetch,
                        WatchPayloadKey.operation.rawValue: WatchUpdateOperation.update.rawValue,
                        WatchPayloadKey.index.rawValue: config.index
                    ]
                    session.sendMessage(payload) { reply in
                        logger.info("sent update to watch, reply \(reply)")
                    }
                }
            }
        default:
            break
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
    }
}
#endif

extension DownloadManager {
    func notifyAppleWatch(result: Result, config: ConfigV2) {
#if os(iOS)
        if WCSession.isSupported() {
            let session = WCSession.default
            watchDelegate = DownloadManagerWatchDelegate(result: result, config: config)
            session.delegate = watchDelegate
            session.activate()
        }
#endif
    }
    
    func emitNotification(result: Result, config: ConfigV2) {
        let content = UNMutableNotificationContent()
        content.title = config.name
        logger.info("emitting notification for result: \(result)")
        switch config.alertType {
        case .everyTime:
            switch config.lastValue {
            case let .StringResult(s):
                content.body = s
            default:
                content.body = "Latest value is \(result.formatted())."
            }
        case .valueChanged:
            switch config.lastValue {
            case let .StringResult(s):
                content.body = s
            default:
                content.body = "Value changed to \(result.formatted())."
            }
        case let .valueIsLessThan(value, equals):
            if equals {
                content.body = "New value \(result.formatted()) is less than or equal to \(value)."
            } else {
                content.body = "New value \(result.formatted()) is less than \(value)."
            }
        case let .valueIsGreaterThan(value, equals):
            if equals {
                content.body = "New value \(result.formatted()) is greater than or equal to \(value)."
            } else {
                content.body = "New value \(result.formatted()) is greater than \(value)."
            }
        default: return
        }
        if config.alertSound {
            content.sound = UNNotificationSound.default
        }
        content.interruptionLevel = .timeSensitive
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        logger.info("sending notification for config \(config.name) with result \(result)")
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let e = error {
                logger.error("failed to send notification with error \(e)")
            }
        }
    }

    static func stringEncoding(charsetName: String) -> String.Encoding {
        switch charsetName.lowercased() {
        case "utf-8", "utf8": return .utf8
        case "utf-16", "utf16": return .utf16
        case "ascii", "us-ascii": return .ascii
        case "iso8859-1", "latin-1", "latin1": return .isoLatin1
        default: return .utf8
        }
    }
    
    static func stringEncoding(response: URLResponse?) -> String.Encoding {
        if let response = response as? HTTPURLResponse {
            if let contentType = response.value(forHTTPHeaderField: "Content-type"), let regex = try? Regex(".*charset=([-_a-zA-Z0-9]+).*") {
                if let match = contentType.firstMatch(of: regex), let charset = match[1].value as? String {
                    return stringEncoding(charsetName: charset)
                }
            }
        }
        return .utf8
    }
    
    func handleDownload(_ response: URLResponse?, _ id: ObjectId, _ location: URL?, _ error: Error?, _ fromBackground: Bool = false) {
        do {
            let realm = try PersistenceV2.shared.realm
            let results = realm.object(ofType: ConfigV2.self, forPrimaryKey: id)
            if let config = results, let u = location, let s = config.selector.notBlank() {
                let result: Result?
                let err: Error?
                do {
                    result = try ValueSelector.applySelector(location: u, selector: s, resultIndex: Int(config.elementIndex), resultType: config.resultType, documentEncoding: DownloadManager.stringEncoding(response: response))
                    err = nil
                } catch {
                    result = nil
                    err = error
                }
                let oldResult = config.lastValue
                if let result = result {
                    if config.isWatchWidget {
                        notifyAppleWatch(result: result, config: config)
                    }
                    switch config.alertType {
                    case .none: break
                    case .everyTime:
                        emitNotification(result: result, config: config)
                    case .valueChanged:
                        if oldResult != result {
                            emitNotification(result: result, config: config)
                        }
                    case let .valueIsGreaterThan(value, equals):
                        switch result {
                        case let .FloatResult(f):
                            if equals {
                                if f >= value {
                                    emitNotification(result: result, config: config)
                                }
                            } else if f > value {
                                emitNotification(result: result, config: config)
                            }
                        case let .PercentResult(f):
                            if equals {
                                if f * 100 >= value {
                                    emitNotification(result: result, config: config)
                                } else if f * 100 > value {
                                    emitNotification(result: result, config: config)
                                }
                            }
                        default: break
                        }
                    case let .valueIsLessThan(value, equals):
                        switch result {
                        case let .FloatResult(f):
                            if equals {
                                if f <= value {
                                    emitNotification(result: result, config: config)
                                }
                            } else if f < value {
                                emitNotification(result: result, config: config)
                            }
                        case let .PercentResult(f):
                            if equals {
                                if f * 100 <= value {
                                    emitNotification(result: result, config: config)
                                } else if f * 100 < value {
                                    emitNotification(result: result, config: config)
                                }
                            }
                        default: break
                        }
                    }
                }
                try realm.write {
                    config.lastFetch = Date()
                    config.lastValue = result
                    config.lastError = err?.localizedDescription
                    let newHistory = HistoryV2(configId: config.id, date: Date(), error: err?.localizedDescription, result: result)
                    let oldHistory = realm.objects(HistoryV2.self).where { h in
                        h.configId == config.id
                    }.sorted(by: { a, b in a.date < b.date }).dropLast(19)
                    for h in oldHistory {
                        realm.delete(h)
                    }
                    realm.add(newHistory)
                }
            }
        } catch {
            logger.error("error updating config \(id): \(error)")
        }
        Scheduler.shared.scheduleConfigs(fromBackground)
    }
}
