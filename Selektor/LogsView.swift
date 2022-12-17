//
//  LogsView.swift
//  Selektor
//
//  Created by Casey Marshall on 12/15/22.
//

import SwiftUI

struct LogEntry: Identifiable {
    let id: Int
    let message: String
}

struct LogsView: View {
    @State var logs: [LogEntry] = []
    var body: some View {
        VStack {
            Button(action: clearLogs) {
                Text("Clear Logs")
            }
            List {
                ForEach(logs) { log in
                    Text(log.message).font(.system(size: 14).monospaced())
                }
            }.onAppear(perform: self.loadLogs)
                .refreshable(action: self.loadLogsAsync)
        }
    }
    
    func clearLogs() {
        try? FileManager.default.removeItem(at: logger.logFile)
        logger.info("logs cleared")
        loadLogs()
    }
    
    func loadLogs() {
        do {
            let logData = try String(contentsOf: logger.logFile, encoding: .utf8)
            logs = logData.split { c in c == "\n" }.reversed().enumerated().map { (i, m) in
                LogEntry(id: i, message: String(m))
            }
        } catch {
            logs = [
                LogEntry(id: 0, message: "error loading logs: \(error)")
            ]
        }
    }
    
    func loadLogsAsync() async {
        await withCheckedContinuation { cont in
            DispatchQueue.main.async {
                loadLogs()
                cont.resume()
            }
        }
    }
}

struct LogsView_Previews: PreviewProvider {
    static var previews: some View {
        LogsView()
    }
}
