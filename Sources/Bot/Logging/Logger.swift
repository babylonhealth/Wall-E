// MARK: LogLevel

/// Different log levels
public enum LogLevel: String, Equatable, CaseIterable {
    /// For more verbose logs used when debugging in depth. Usually provides a lot of details
    case debug
    /// For informative logs, like state changes
    case info
    /// For reporting errors and failures
    case error
}

extension LogLevel: Comparable {
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        let index = LogLevel.allCases.firstIndex(of:)
        return index(lhs)! < index(rhs)!
    }
}


// MARK: LoggerProtocol

public protocol LoggerProtocol {
    /// Logs an encodable at the provided log level The encodable can be encoded to the required format.
    /// The log level indicates the type of log and/or severity
    ///
    /// Normally, you will use one of the convenience methods (i.e., `verbose(...)`, `info(...)`).
    func log(_ string: String, at level: LogLevel, file: String, function: String, line: UInt, column: UInt)
}

extension LoggerProtocol {
    /// Debug logs are used to debug problems
    public func debug(_ string: String, file: String = #file, function: String = #function, line: UInt = #line, column: UInt = #column) {
        self.log(string, at: .debug, file: file, function: function, line: line, column: column)
    }

    /// Info logs are used to indicate a specific infrequent event occurring.
    public func info(_ string: String, file: String = #file, function: String = #function, line: UInt = #line, column: UInt = #column) {
        self.log(string, at: .info, file: file, function: function, line: line, column: column)
    }

    /// Error, indicates something went wrong and a part of the execution was failed.
    public func error(_ string: String, file: String = #file, function: String = #function, line: UInt = #line, column: UInt = #column) {
        self.log(string, at: .error, file: file, function: function, line: line, column: column)
    }
}
