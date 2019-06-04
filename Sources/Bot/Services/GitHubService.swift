import Foundation
import ReactiveSwift
import Result

public final class GitHubService {

    internal enum HTTPHeader: String {
        case event = "X-GitHub-Event"
    }

    internal enum APIEvent: String {
        case pullRequest = "pull_request"
        case ping
    }

    private let eventsObserver: Signal<Event, NoError>.Observer
    public let events: Signal<Event, NoError>

    public init() {
        (events, eventsObserver) = Signal.pipe()
    }

    public func handleEvent(from request: RequestProtocol) -> Result<Void, EventHandlingError> {
        return parseEvent(from: request)
            .analysis(
                ifSuccess: { event in
                    eventsObserver.send(value: event)
                    return .success(())
                },
                ifFailure: Result.failure
            )
    }

    private func parseEvent(from request: RequestProtocol) -> Result<Event, EventHandlingError> {
        guard let rawEvent = request.header(.event)
            else { return .failure(.invalid) }

        switch APIEvent(rawValue: rawEvent) {
        case .pullRequest?:
            return Result(request.decodeBody(PullRequestEvent.self), failWith: .invalid)
                .map(Event.pullRequest)
        case .ping?:
            return .success(.ping)
        case .none:
            return .failure(.unknown)
        }
    }
}

extension GitHubService {
    public enum EventHandlingError: Error {
        case invalid
        case unknown
    }
}

private extension RequestProtocol {
    func header(_ header: GitHubService.HTTPHeader) -> String? {
        return self.header(named: header.rawValue)
    }
}
