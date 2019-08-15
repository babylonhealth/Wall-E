import Bot
import Vapor

public func routes(_ router: Router, logger: LoggerProtocol, gitHubEventsService: GitHubEventsService) throws {

    router.post("github") { request -> HTTPResponse in
        logger.log("Received request: \(request)")
        switch gitHubEventsService.handleEvent(from: request).first() {
        case .success?:
            logger.log("Handled request: \(request)")
            return HTTPResponse(status: .ok)
        case .failure?, .none:
            logger.log("Handled request: \(request)")
            return HTTPResponse(status: .badRequest)
        }
    }
}
