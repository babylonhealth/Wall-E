import Foundation
import ReactiveSwift
import Result

public final class GitHubService {
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
        guard let event = request.header(named: "X-GitHub-Event")
            else { return .failure(.invalid) }

        switch event {
        case "pull_request":
            return Result(request.decodeBody(PullRequestEvent.self), failWith: .invalid)
                .map(Event.pullRequest)
        case "ping":
            return .success(.ping)
        default:
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
