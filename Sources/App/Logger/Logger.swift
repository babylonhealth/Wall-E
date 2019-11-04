import Vapor
import Bot

public final class PrintLogger: LoggerProtocol, Service {
    public func log(_ message: String) {
        print("\(Date()) | [WALL-E] \(message)")
    }
}
