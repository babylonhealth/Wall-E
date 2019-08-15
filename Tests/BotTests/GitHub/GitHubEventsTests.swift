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

                return service.handleEvent(from: req).first()
            },
            assert: { result, events in
                expect(result?.error).to(beNil())
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

                return service.handleEvent(from: req).first()
            },
            assert: { result, events in
                expect(result?.error).to(beNil())
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

                return service.handleEvent(from: req).first()
            },
            assert: { result, events in
                expect(result?.error) == .unknown
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

                return service.handleEvent(from: req).first()
            },
            assert: { result, events in
                expect(result?.error) == .untrustworthy
                expect(events) == []
            }
        )
    }
}

extension GitHubEventsTests {
    
    static let signatureToken = "Wall-E"

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
        stub: (TestScheduler) -> GitHubEventsService = stubService,
        when: (GitHubEventsService, TestScheduler) -> Result<Void, GitHubEventsService.EventHandlingError>?,
        assert: (Result<Void, GitHubEventsService.EventHandlingError>?, [Event]) -> Void
    ) {

        let scheduler = TestScheduler()

        let service = stub(scheduler)

        var observedEvents: [Event] = []

        service.events
            .observe(on: scheduler)
            .observeValues { event in observedEvents.append(event) }

        let result = when(service, scheduler)

        scheduler.advance()

        assert(result, observedEvents)
    }

    private static func stubService(_ scheduler: TestScheduler) -> GitHubEventsService {
        return GitHubEventsService(signatureToken: signatureToken, logger: MockLogger(), scheduler: scheduler)
    }

    private func request(with event: GitHubEventsService.APIEvent, signature: String, payload: String) -> StubbedRequest {
        return request(with: event, signature: signature, payload: payload.data(using: .utf8))
    }

    private func request(withRawEvent rawEvent: String, signature: String, payload: String) -> StubbedRequest {
        return request(withRawEvent: rawEvent, signature: signature, payload: payload.data(using: .utf8))
    }

    private func request(with event: GitHubEventsService.APIEvent, signature: String, payload: Data?) -> StubbedRequest {
        return request(withRawEvent: event.rawValue, signature: signature, payload: payload)
    }

    private func request(withRawEvent rawEvent: String, signature: String, payload: Data?) -> StubbedRequest {
        return StubbedRequest(
            headers: [
                GitHubEventsService.HTTPHeader.event.rawValue: rawEvent,
                GitHubEventsService.HTTPHeader.signature.rawValue: "sha1=\(signature)"
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

        public func decodeBody<T>(_ type: T.Type) -> Result<T, AnyError> where T: Decodable {
            guard let data = data
                else { return .failure(AnyError(DecodeError.invalid)) }

            do {
                let decoder = JSONDecoder()
                return .success(try decoder.decode(T.self, from: data))
            } catch {
                return .failure(AnyError(DecodeError.invalid))
            }
        }
    }
}
