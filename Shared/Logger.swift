import Foundation
import os.log

class Logger {
    private static let subsystem = "me.sokolov.wpadproxy"
    private static let category = "General"
    private static let osLog = OSLog(subsystem: subsystem, category: category)
    
    static func log(_ message: String, type: OSLogType = .default) {
        os_log("%{public}@", log: osLog, type: type, message)
        
        #if DEBUG
        print("[\(Date())] \(message)")
        #endif
        
        saveToFile(message)
    }
    
    static func error(_ message: String) {
        log(message, type: .error)
    }
    
    static func debug(_ message: String) {
        log(message, type: .debug)
    }
    
    static func info(_ message: String) {
        log(message, type: .info)
    }
    
    private static func saveToFile(_ message: String) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.me.sokolov.wpadproxy"
        ) else { return }
        
        let logURL = containerURL.appendingPathComponent("logs.txt")
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)\n"
        
        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logURL)
            }
        }
    }
    
    static func getLogs() -> String {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.me.sokolov.wpadproxy"
        ) else { return "" }
        
        let logURL = containerURL.appendingPathComponent("logs.txt")
        return (try? String(contentsOf: logURL)) ?? ""
    }
    
    static func clearLogs() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.me.sokolov.wpadproxy"
        ) else { return }
        
        let logURL = containerURL.appendingPathComponent("logs.txt")
        try? FileManager.default.removeItem(at: logURL)
    }
}