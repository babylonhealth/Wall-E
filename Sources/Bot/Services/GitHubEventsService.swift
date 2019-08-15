import Foundation
import ReactiveSwift
import Result
import CryptoSwift

public protocol GitHubEventsServiceProtocol {
    var events: Signal<Event, NoError> { get }
}

public final class GitHubEventsService: GitHubEventsServiceProtocol {

    internal enum HTTPHeader: String {
        case event = "X-GitHub-Event"
        case signature = "X-Hub-Signature"
    }

    internal enum APIEvent: String {
        case pullRequest = "pull_request"
        case status
        case ping
    }

    public typealias Token = String

    private let scheduler: Scheduler
    private let signatureVerifier: (RequestProtocol) -> Result<RequestProtocol, EventHandlingError>
    private let eventsObserver: Signal<Event, NoError>.Observer
    private let logger: LoggerProtocol
    public let events: Signal<Event, NoError>

    public init(signatureToken: Token, logger: LoggerProtocol, scheduler: Scheduler = QueueScheduler()) {
        self.signatureVerifier = GitHubEventsService.signatureVerifier(with: signatureToken)
        self.logger = logger
        self.scheduler = scheduler
        (events, eventsObserver) = Signal.pipe()
    }

    public func handleEvent(from request: RequestProtocol) -> SignalProducer<Void, EventHandlingError> {
        return SignalProducer { [signatureVerifier] in signatureVerifier(request) }
            .flatMap(.latest, parseEvent)
            .on(value: eventsObserver.send(value:))
            .map { _ in }
    }

    private func parseEvent(from request: RequestProtocol) -> SignalProducer<Event, EventHandlingError> {
        guard let rawEvent = request.header(.event)
            else { return SignalProducer(error: .invalid) }

        switch APIEvent(rawValue: rawEvent) {
        case .pullRequest?:
            return decode(Event.pullRequest, from: request)
        case .status?:
            return decode(Event.status, from: request)
        case .ping?:
            return SignalProducer(value: .ping)
        case .none:
            return SignalProducer(error: .unknown)
        }
    }

    private func decode<T: Decodable>(
        _ transform: @escaping (T) -> Event,
        from request: RequestProtocol
    ) -> SignalProducer<Event, EventHandlingError> {
        return request.decodeBody(T.self, using: scheduler)
            .on(failed: { [logger] error in logger.log("Failed to decode `\(T.self)`: \(error)") })
            .mapError { _ in EventHandlingError.invalid }
            .map(transform)
    }

    private static func signatureVerifier(
        with token: Token
    ) -> (RequestProtocol) -> Result<RequestProtocol, EventHandlingError> {

        // This was implemented following this reference: https://developer.github.com/webhooks/securing/

        return { request in
            guard
                let signature = request.header(.signature),
                let digest = signature.range(of: "sha1=")
                    .map({ signature[$0.upperBound..<signature.endIndex] })
                    .map(String.init)
                    .map(Array.init(hex:))
                else { return .failure(.untrustworthy) }

            guard
                let bodyData = request.body.data,
                let computedDigest = try? HMAC(key: token, variant: .sha1).authenticate(bodyData.bytes)
                else { return .failure(.untrustworthy) }

            guard computedDigest == digest
                else { return .failure(.untrustworthy) }

            return .success(request)
        }
    }
}

extension GitHubEventsService {
    public enum EventHandlingError: Error {
        case untrustworthy
        case invalid
        case unknown
    }
}

private extension RequestProtocol {
    func header(_ header: GitHubEventsService.HTTPHeader) -> String? {
        return self.header(named: header.rawValue)
    }
}
