import Bot
import Vapor

public func routes(_ router: Router, logger: LoggerProtocol, gitHubService: GitHubService) throws {

    router.post("github") { request -> HTTPResponse in

        logger.log("📨 handling event: \(request)")

        switch gitHubService.handleEvent(from: request).first() {
        case .success?:
            return HTTPResponse(status: .ok)
        case .failure?, .none:
            return HTTPResponse(status: .badRequest)
        }
    }
}
