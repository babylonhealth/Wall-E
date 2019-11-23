import Bot
import Vapor

public func routes(
    _ router: Router,
    logger: LoggerProtocol,
    mergeService: MergeService,
    gitHubEventsService: GitHubEventsService
) throws {

    router.get("/") { request -> Response in
        let response = Response(using: request)
        if request.header(named: HTTPHeaderName.accept.description) == "application/json" {
            try response.content.encode(mergeService.state.value, as: .json)
        } else {
            try response.content.encode(String(describing: mergeService.state.value), as: .plainText)
        }
        return response
    }

    router.get("health") { request -> HTTPResponse in
        switch mergeService.healthcheck.status.value {
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
