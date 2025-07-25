import os


enum LogLevel: String {
    case `default`
    case debug
    case info
    case error
    case fault
}


private func _log(_ level: LogLevel = .default, _ message: StaticString, _ args: CVarArg...) {
    if #available(OSX 10.14, *) {
        let type: OSLogType
        switch level {
            case .default: type = .default
            case .debug: type = .debug
            case .info: type = .info
            case .error: type = .error
            case .fault: type = .fault
        }
        os_log(type, message, args)
    }
}


private func _isDebugAssertConfiguration() -> Bool {
    #if DEBUG
    return true
    #else
    return false
    #endif
}

func log(_ level: LogLevel = .default, _ message: String) {
    if _isDebugAssertConfiguration() {
        print("\(level.rawValue): \(message)")
    } else {
        _log(level, "%@", message)
    }
}
