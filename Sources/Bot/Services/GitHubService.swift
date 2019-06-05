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

    private let scheduler: QueueScheduler
    private let eventsObserver: Signal<Event, NoError>.Observer
    public let events: Signal<Event, NoError>

    public init(scheduler: QueueScheduler = QueueScheduler()) {
        self.scheduler = scheduler
        (events, eventsObserver) = Signal.pipe()
    }

    public func handleEvent(from request: RequestProtocol) -> SignalProducer<Void, EventHandlingError> {
        return parseEvent(from: request)
            .on(value: eventsObserver.send(value:))
            .map { _ in }
    }

    private func parseEvent(from request: RequestProtocol) -> SignalProducer<Event, EventHandlingError> {
        guard let rawEvent = request.header(.event)
            else { return SignalProducer(error: .invalid) }

        switch APIEvent(rawValue: rawEvent) {
        case .pullRequest?:
            return request.decodeBody(PullRequestEvent.self, using: scheduler)
                .mapError { _ in EventHandlingError.invalid }
                .map(Event.pullRequest)
        case .ping?:
            return SignalProducer(value: .ping)
        case .none:
            return SignalProducer(error: .unknown)
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
