import Bot
import Vapor

public func routes(
    _ router: Router,
    logger: LoggerProtocol,
    dispatchService: DispatchService,
    gitHubEventsService: GitHubEventsService
) throws {

    router.get("/") { request -> String in
        return dispatchService.queuesDescription
    }

    router.get("health") { request -> HTTPResponse in
        switch dispatchService.healthcheck.status.value {
        case .ok: return HTTPResponse(status: .ok)
        default: return HTTPResponse(status: .serviceUnavailable)
        }
    }

    router.post("github") { request -> HTTPResponse in
        switch gitHubEventsService.handleEvent(from: request).first() {
        case .success?:
            return HTTPResponse(status: .ok)
        case .failure?, .none:
            return HTTPResponse(status: .badRequest)
        }
    }
}
