import Bot
import Vapor

public func routes(_ router: Router) throws {

    router.post("github") { request -> HTTPResponse in

        let logger = try request.make(LoggerProtocol.self)
        let service = try request.make(GitHubService.self)

        logger.log("📨 handling event: \(request)")

        switch service.handleEvent(from: request).first() {
        case .success?:
            return HTTPResponse(status: .ok)
        case .failure?, .none:
            return HTTPResponse(status: .badRequest)
        }
    }
}
