import XCTest
import Nimble
import Result
import ReactiveSwift
import CryptoSwift
@testable import Bot

class GitHubEventsTests: XCTestCase {

    func test_handling_pull_request_event() {
        perform(
            when: { service, scheduler in

                let req = request(
                    with: .pullRequest,
                    signature: "00faadd5dc1395b616a546ac6f67796409b4f839",
                    payload: GitHubPullRequestEvent.data(using: .utf8)
                )

                let result = service.handleEvent(from: req).first()

                scheduler.advance()

                expect(result?.error).to(beNil())
            },
            assert: { events in
                expect(events) == [Event.pullRequest(stubbedPullRequestEvent)]
            }
        )
    }

    func test_handling_ping_event() {
        perform(
            when: { service, scheduler in

                // NOTE: I'm unsure about the payload of this specific event
                let req = request(
                    with: .ping,
                    signature: "9f64868b5cd91faa4c63589acff7286b16d289ae",
                    payload: "{}"
                )

                let result = service.handleEvent(from: req).first()

                scheduler.advance()

                expect(result?.error).to(beNil())
            },
            assert: { events in
                expect(events) == [Event.ping]
            }
        )
    }

    func test_handling_unknown_event() {
        perform(
            when: { service, scheduler in

                let req = request(
                    withRawEvent: "anything_really",
                    signature: "9f64868b5cd91faa4c63589acff7286b16d289ae",
                    payload: "{}"
                )

                let result = service.handleEvent(from: req).first()

                expect(result?.error) == .unknown
            },
            assert: { events in
                expect(events) == []
            }
        )
    }

    func test_handling_untrustworthy_payload() {
        perform(
            when: { service, scheduler in

                let req = request(
                    withRawEvent: "anything_really",
                    signature: "00faadd5dc1395b616a546ac6f67796409b4f839",
                    payload: "{}"
                )

                let result = service.handleEvent(from: req).first()

                expect(result?.error) == .untrustworthy
            },
            assert: { events in
                expect(events) == []
            }
        )
    }
}

extension GitHubEventsTests {
    
    static let signatureToken = "Wall-E"

    private func signature(for data: Data) -> String {
        return try! HMAC(key: GitHubEventsTests.signatureToken, variant: .sha1)
            .authenticate(data.bytes)
            .toHexString()
    }

    private var stubbedPullRequestEvent: PullRequestEvent {
        return PullRequestEvent(
            action: .closed,
            pullRequestMetadata: PullRequestMetadata(
                reference: PullRequest(
                    number: 1,
                    title: "Update the README with new information",
                    author: PullRequest.Author(login: "Codertocat"),
                    source: PullRequest.Branch(ref: "changes", sha: "34c5c7793cb3b279e22454cb6750c80560547b3a"),
                    target: PullRequest.Branch(ref: "master", sha: "a10867b14bb761a232cd80139fbd4c0d33264240"),
                    labels: [.init(name: "bug")]
                ),
                isMerged: false,
                mergeState: .clean
            )
        )
    }

    private func perform(
        stub: (TestScheduler) -> GitHubService = stubService,
        when: (GitHubService, TestScheduler) -> Void,
        assert: ([Event]) -> Void
        ) {

        let scheduler = TestScheduler()

        let service = stub(scheduler)

        var observedEvents: [Event] = []

        service.events
            .observe(on: scheduler)
            .observeValues { event in observedEvents.append(event) }

        when(service, scheduler)

        assert(observedEvents)
    }

    private static func stubService(_ scheduler: TestScheduler) -> GitHubService {
        return GitHubService(signatureToken: signatureToken, scheduler: scheduler)
    }

    private func request(with event: GitHubService.APIEvent, signature: String, payload: String) -> StubbedRequest {
        return request(with: event, signature: signature, payload: payload.data(using: .utf8))
    }

    private func request(withRawEvent rawEvent: String, signature: String, payload: String) -> StubbedRequest {
        return request(withRawEvent: rawEvent, signature: signature, payload: payload.data(using: .utf8))
    }

    private func request(with event: GitHubService.APIEvent, signature: String, payload: Data?) -> StubbedRequest {
        return request(withRawEvent: event.rawValue, signature: signature, payload: payload)
    }

    private func request(withRawEvent rawEvent: String, signature: String, payload: Data?) -> StubbedRequest {
        return StubbedRequest(
            headers: [
                GitHubService.HTTPHeader.event.rawValue: rawEvent,
                GitHubService.HTTPHeader.signature.rawValue: "sha1=\(signature)"
            ],
            data: payload
        )
    }
}

extension GitHubEventsTests {
    enum DecodeError: Error {
        case invalid
    }

    fileprivate struct StubbedRequest: RequestProtocol, HTTPBodyProtocol {
        let headers: [String: String]
        let data: Data?

        var body: HTTPBodyProtocol {
            return self
        }

        func header(named name: String) -> String? {
            return headers[name]
        }

        public func decodeBody<T>(
            _ type: T.Type,
            using scheduler: Scheduler
        ) -> SignalProducer<T, AnyError> where T: Decodable {
            guard let data = data
                else { return SignalProducer(error: AnyError(DecodeError.invalid)) }

            do {
                let decoder = JSONDecoder()
                return SignalProducer(value: try decoder.decode(T.self, from: data))
            } catch {
                return SignalProducer(error: AnyError(DecodeError.invalid))
            }
        }
    }
}
