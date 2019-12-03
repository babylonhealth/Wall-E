import Bot
import Vapor

public func routes(
    _ router: Router,
    logger: LoggerProtocol,
    dispatchService: DispatchService,
    gitHubEventsService: GitHubEventsService
) throws {

    router.get("/") { request -> Response in
        let response = Response(using: request)
        if request.header(named: HTTPHeaderName.accept.description) == "application/json" {
            try response.content.encode(dispatchService.queueStates, as: .json)
        } else {
            try response.content.encode(dispatchService.queuesDescription, as: .plainText)
        }
        return response
    }

    router.get("health") { request -> HTTPResponse in
        switch dispatchService.healthcheckStatus {
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
