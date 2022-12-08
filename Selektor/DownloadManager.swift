//
//  DownloadManager.swift
//  Selektor
//
//  Created by Casey Marshall on 12/6/22.
//

import Foundation
import CoreData

class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    
    private var urlSession: URLSession = URLSession.shared
    @Published var tasks: [URLSessionTask] = []
    @Published var completedTasks: [(URLSessionTask, URL?, Error?)] = []
    
    override private init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: backgroundId)
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
        updateTasks()
    }
    
    func startDownload(url: URL, with headers: Dictionary<String, String> = [:]) {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        headers.forEach { (k, v) in
            request.setValue(v, forHTTPHeaderField: k)
        }
        request.setValue(lynxUserAgent, forHTTPHeaderField: "User-agent")
        request.setValue("text/html, text/plain, text/sgml, text/css, application/xhtml+xml, */*;q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("en", forHTTPHeaderField: "Accept-Language")
        let task = urlSession.downloadTask(with: request)
        task.resume()
        tasks.append(task)
    }
    
    func updateTasks() {
        urlSession.getAllTasks { tasks in
            DispatchQueue.main.async {
                self.tasks = tasks
            }
        }
    }
}

extension DownloadManager : URLSessionDelegate, URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        self.tasks = self.tasks.filter { t in t != downloadTask }
        if let idStr = downloadTask.currentRequest?.value(forHTTPHeaderField: configIdHeaderKey), let id = UUID(uuidString: idStr) {
            self.handleDownload(id, location, nil)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.tasks = self.tasks.filter { t in t != task }
        if let idStr = task.currentRequest?.value(forHTTPHeaderField: configIdHeaderKey), let id = UUID(uuidString: idStr) {
            self.handleDownload(id, nil, error)
        }
    }
}

extension DownloadManager {
    func handleDownload(_ id: UUID, _ location: URL?, _ error: Error?) {
        let viewContext = PersistenceController.shared.container.viewContext
        let request = NSFetchRequest<Config>(entityName: "Config")
        request.predicate = NSPredicate(format: "id = %@", argumentArray: [id])
        do {
            let results = try viewContext.fetch(request)
            if let config = results.first, let u = location, let s = config.selector, let ts = config.resultType, let t = ResultType.from(tag: ts) {
                let result: Result?
                let err: Error?
                do {
                    result = try ValueSelector.applySelector(location: u, selector: s, resultIndex: Int(config.elementIndex), resultType: t)
                    err = nil
                } catch {
                    result = nil
                    err = error
                }
                config.lastFetch = Date()
                config.result = result
                config.lastError = err?.localizedDescription
                let newHistory = History(context: viewContext)
                newHistory.id = UUID()
                newHistory.date = Date()
                newHistory.configId = id
                newHistory.result = result
                newHistory.error = err?.localizedDescription
                try viewContext.save()
                let historyRequest = NSFetchRequest<History>(entityName: "History")
                historyRequest.predicate = NSPredicate(format: "configId = %@", argumentArray: [id])
                historyRequest.sortDescriptors = [NSSortDescriptor(keyPath: \History.date, ascending: true)]
                let history = try viewContext.fetch(historyRequest)
                if history.count > 20 {
                    let h = history.dropLast(20)
                    h.forEach { e in
                        viewContext.delete(e)
                    }
                    try viewContext.save()
                }
            }
        } catch {
            print("error updating config \(id): \(error)")
        }
        Scheduler.shared.scheduleConfigs()
    }
}
