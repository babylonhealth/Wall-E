import Foundation
import Vapor

public final class JSONLogger: Logger, Service {
    let serializer = JSONEncoder()
    let minimumLogLevel: LogLevel = .verbose
    
    public func log(_ string: String, at level: LogLevel,
                    file: String = #file, function: String = #function, line: UInt = #line, column: UInt = #column
    ) {
        guard level.isAtLeast(minimumLevel: minimumLogLevel) else { return }
        let formatted: String
        do {
            let message = LogMessage(
                timestamp: Date(),
                message: string,
                level: level,
                file: file,
                function: function,
                line: line,
                column: column
            )
            let data = try serializer.encode(message)
            formatted = String(data: data, encoding: .utf8)!
        } catch {
            formatted = "[\(Date())] [\(level.description)] \(string)"
        }
        // We need to print to stdout for our Logz.io instance to pick up the JSON log message
        print(formatted)
    }
}

// MARK: Private structure of LogMessage

extension JSONLogger {
    struct LogMessage: Encodable {
        let timestamp: Date
        let message: String
        let level: LogLevel
        let file: String
        let function: String
        let line: UInt
        let column: UInt

        static var dateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd'T'hh:mm:ss.SSSZ"
            df.locale = Locale(identifier: "en_US_POSIX")
            return df
        }()

        enum CodingKeys: String, CodingKey {
            case timestamp = "@timestamp"
            case message = "message"
            case level = "level"
            case context = "context"
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(LogMessage.dateFormatter.string(from: self.timestamp), forKey: .timestamp)
            try container.encode(self.message, forKey: .message)
            try container.encode(self.level.description, forKey: .level)
            let context = "\(file):\(line):\(column) - \(function)"
            try container.encode(context, forKey: .context)
        }
    }
}
