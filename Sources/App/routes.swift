import Bot
import Vapor
import ReactiveSwift

public func routes(_ router: Router, logger: LoggerProtocol, scheduler: Scheduler, gitHubEventsService: GitHubEventsService) throws {

    router.post("github") { request -> EventLoopFuture<HTTPResponse> in

        let promise = request.eventLoop.newPromise(HTTPResponse.self)

        gitHubEventsService.handleEvent(from: request)
            .start(on: scheduler)
            .startWithResult { result in
                switch result {
                case .success:
                    promise.succeed(result: HTTPResponse(status: .ok))
                case .failure:
                    promise.succeed(result: HTTPResponse(status: .badRequest))
                }
        }

        return promise.futureResult
    }
}
