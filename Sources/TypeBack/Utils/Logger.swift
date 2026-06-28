import Foundation
import os.log

/// 日志级别
enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }

    /// 等级优先级（数字越大越严重），用于阈值过滤
    var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        }
    }
}

/// 结构化日志系统
final class Logger {
    // MARK: - 单例
    static let shared = Logger()

    // MARK: - 配置
    private let subsystem = "com.typeback.app"
    private let category = "main"
    private let osLogger: OSLog

    private var logFileURL: URL?
    private let maxLogFileSize: Int = 2 * 1024 * 1024 // 2MB
    private let maxLogFiles: Int = 2
    /// 文件落盘等级阈值：低于此等级的日志只走 OSLog，不写文件
    private let minFileLogLevel: LogLevel = .info

    // MARK: - 队列
    private let logQueue = DispatchQueue(label: "com.typeback.logger", qos: .utility)

    // MARK: - 初始化
    private init() {
        osLogger = OSLog(subsystem: subsystem, category: category)
        setupLogFile()
    }

    // MARK: - 日志方法
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }

    func error(_ message: String, error: Swift.Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var logMessage = message
        if let error = error {
            logMessage += " | Error: \(error)"
        }
        log(.error, logMessage, file: file, function: function, line: line)
    }

    // MARK: - 私有方法
    private func log(_ level: LogLevel, _ message: String, file: String, function: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)"

        // 输出到 OSLog（Console.app 可见，所有等级）
        os_log("%@", log: osLogger, type: level.osLogType, logMessage)

        // 文件落盘：仅 minFileLogLevel 及以上等级写入，避免 DEBUG 噪声
        guard level.priority >= minFileLogLevel.priority else { return }
        logQueue.async { [weak self] in
            self?.writeToFile(logMessage)
        }
    }

    private func setupLogFile() {
        guard let documentsPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        let appPath = documentsPath.appendingPathComponent("TypeBack", isDirectory: true)
        try? FileManager.default.createDirectory(at: appPath, withIntermediateDirectories: true)

        logFileURL = appPath.appendingPathComponent("typeback.log")
    }

    private func writeToFile(_ message: String) {
        guard let logFileURL = logFileURL else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) \(message)\n"

        // 检查文件大小
        if let attributes = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
           let fileSize = attributes[.size] as? Int,
           fileSize > maxLogFileSize {
            rotateLogFiles()
        }

        // 追加写入
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    _ = fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }

    private func rotateLogFiles() {
        guard let logFileURL = logFileURL else { return }

        // 删除最旧的日志文件
        let oldestLog = logFileURL.deletingPathExtension().appendingPathExtension("\(maxLogFiles).log")
        try? FileManager.default.removeItem(at: oldestLog)

        // 轮转其他日志文件
        for i in (1..<maxLogFiles).reversed() {
            let current = logFileURL.deletingPathExtension().appendingPathExtension("\(i).log")
            let next = logFileURL.deletingPathExtension().appendingPathExtension("\(i+1).log")
            try? FileManager.default.moveItem(at: current, to: next)
        }

        // 移动当前日志文件
        let backup = logFileURL.deletingPathExtension().appendingPathExtension("1.log")
        try? FileManager.default.moveItem(at: logFileURL, to: backup)
    }
}

// MARK: - 便捷宏
func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, file: file, function: function, line: line)
}

func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, file: file, function: function, line: line)
}

func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, file: file, function: function, line: line)
}

func logError(_ message: String, error: Swift.Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, error: error, file: file, function: function, line: line)
}
