import Foundation
import ReactiveSwift
import Result
import CryptoSwift

public final class GitHubService {

    internal enum HTTPHeader: String {
        case event = "X-GitHub-Event"
        case signature = "X-Hub-Signature"
    }

    internal enum APIEvent: String {
        case pullRequest = "pull_request"
        case ping
    }

    public typealias Token = String

    private let scheduler: Scheduler
    private let signatureVerifier: (RequestProtocol) -> Result<RequestProtocol, EventHandlingError>
    private let eventsObserver: Signal<Event, NoError>.Observer
    public let events: Signal<Event, NoError>

    public init(signatureToken: Token, scheduler: Scheduler = QueueScheduler()) {
        self.signatureVerifier = GitHubService.signatureVerifier()(signatureToken)
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
            return request.decodeBody(PullRequestEvent.self, using: scheduler)
                .mapError { _ in EventHandlingError.invalid }
                .map(Event.pullRequest)
        case .ping?:
            return SignalProducer(value: .ping)
        case .none:
            return SignalProducer(error: .unknown)
        }
    }

    private static func signatureVerifier(
    ) -> (Token) -> (RequestProtocol) -> Result<RequestProtocol, EventHandlingError> {

        return { token in
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
}

extension GitHubService {
    public enum EventHandlingError: Error {
        case untrustworthy
        case invalid
        case unknown
    }
}

private extension RequestProtocol {
    func header(_ header: GitHubService.HTTPHeader) -> String? {
        return self.header(named: header.rawValue)
    }
}
