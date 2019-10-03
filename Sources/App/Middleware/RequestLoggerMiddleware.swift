import Vapor
import Bot

final class RequestLoggerMiddleware: Middleware, ServiceType {
    private let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    func respond(to request: Request, chainingTo next: Responder) throws -> Future<Vapor.Response> {
        logger.log("""
        📝 Request logger 📝
        \(request)
        ===========================
        """)
        return try next.respond(to: request)
    }

    static func makeService(for container: Container) throws -> RequestLoggerMiddleware {
        return RequestLoggerMiddleware(logger: try container.make(PrintLogger.self))
    }
}
