import Bot
import Vapor

public func routes(_ router: Router, gitHubService: GitHubService) throws {

    router.post("github") { request -> HTTPResponse in
        switch gitHubService.handleEvent(from: request) {
        case .success:
            return HTTPResponse(status: .ok)
        case .failure:
            return HTTPResponse(status: .badRequest)
        }
    }
}
