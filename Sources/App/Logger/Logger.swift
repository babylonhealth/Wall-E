import Bot

public final class PrintLogger: LoggerProtocol {
    public func log(_ message: String) {
        print("[WALL-E] \(message)")
    }
}
