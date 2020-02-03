import Vapor

final class RequestLoggerMiddleware: Middleware, ServiceType {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func respond(to request: Request, chainingTo next: Responder) throws -> Future<Vapor.Response> {
        logger.debug("""
            📝 Request logger 📝
            \(request)
            ===========================
            """
        )
        return try next.respond(to: request)
    }

    static func makeService(for container: Container) throws -> RequestLoggerMiddleware {
        return RequestLoggerMiddleware(logger: try container.make(Logger.self))
    }
}
