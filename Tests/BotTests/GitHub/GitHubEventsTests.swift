import XCTest
import Nimble
import Result
import ReactiveSwift
@testable import Bot

class GitHubEventsTests: XCTestCase {

    func test_handling_pull_request_event() {
        let service = GitHubService()
        let scheduler = TestScheduler()

        let pullRequestEvent = PullRequestEvent(
            action: .opened,
            pullRequestMetadata: PullRequestMetadata(
                reference: PullRequest(
                    number: 1,
                    title: "Hello World",
                    author: PullRequest.Author(login: "Wall-E Bot"),
                    source: PullRequest.Branch(ref: "some-feature", sha: "123"),
                    target: PullRequest.Branch(ref: "master", sha: "123"),
                    labels: []
                ),
                isMerged: false,
                mergeState: .clean
            )
        )

        let request = StubbedRequest(
            headers: [GitHubService.HTTPHeader.event.rawValue: GitHubService.APIEvent.pullRequest.rawValue],
            body: pullRequestEvent
        )

        var observedEvents: [Event] = []

        service.events
            .observe(on: scheduler)
            .observeValues { event in observedEvents.append(event) }

        let result = service.handleEvent(from: request).first()

        scheduler.advance()

        expect(result?.error).to(beNil())
        expect(observedEvents) == [Event.pullRequest(pullRequestEvent)]
    }

    func test_handling_ping_event() {
        let service = GitHubService()
        let scheduler = TestScheduler()

        let request = StubbedRequest(
            headers: [GitHubService.HTTPHeader.event.rawValue: GitHubService.APIEvent.ping.rawValue],
            body: nil
        )

        var observedEvents: [Event] = []

        service.events
            .observe(on: scheduler)
            .observeValues { event in observedEvents.append(event) }

        let result = service.handleEvent(from: request).first()

        scheduler.advance()

        expect(result?.error).to(beNil())
        expect(observedEvents) == [Event.ping]
    }

    func test_handling_unknown_event() {
        let service = GitHubService()

        let request = StubbedRequest(
            headers: [GitHubService.HTTPHeader.event.rawValue : "anything_really"],
            body: nil
        )

        let result = service.handleEvent(from: request).first()

        expect(result?.error) == .unknown
    }
}

extension GitHubEventsTests {
    enum DecodeError: Error {
        case invalid
    }

    fileprivate struct StubbedRequest: RequestProtocol {
        let headers: [String: String]
        let body: Any?

        func header(named name: String) -> String? {
            return headers[name]
        }

        public func decodeBody<T>(
            _ type: T.Type,
            using scheduler: QueueScheduler
        ) -> SignalProducer<T, AnyError> where T: Decodable {
            switch body as? T {
            case let .some(value):
                return SignalProducer(value: value)
            case .none:
                return SignalProducer(error: AnyError(DecodeError.invalid))
            }
        }
    }
}
