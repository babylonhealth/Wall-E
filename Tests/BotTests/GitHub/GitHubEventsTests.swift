import XCTest
import Nimble
import Result
import ReactiveSwift
import CryptoSwift
@testable import Bot

class GitHubEventsTests: XCTestCase {

    let signatureToken = "Wall-E"

    private func signature(for data: Data) -> String {
        let signature = try! HMAC(key: signatureToken, variant: .sha1)
            .authenticate(data.bytes)
            .toHexString()

        return "sha1=\(signature)"
    }

    func test_handling_pull_request_event() {
        let service = GitHubService(signatureToken: signatureToken)
        let scheduler = TestScheduler()

        let pullRequestEvent = PullRequestEvent(
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

        let request = StubbedRequest(
            headers: [
                GitHubService.HTTPHeader.event.rawValue: GitHubService.APIEvent.pullRequest.rawValue,
                GitHubService.HTTPHeader.signature.rawValue: signature(for: GitHubPullRequestEvent.data(using: .utf8)!)
            ],
            data: GitHubPullRequestEvent.data(using: .utf8)!
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
        let service = GitHubService(signatureToken: signatureToken)
        let scheduler = TestScheduler()

        // NOTE: I'm unsure about the payload of this specific event
        let payload = "{}".data(using: .utf8)!

        let request = StubbedRequest(
            headers: [
                GitHubService.HTTPHeader.event.rawValue: GitHubService.APIEvent.ping.rawValue,
                GitHubService.HTTPHeader.signature.rawValue: signature(for: payload)
            ],
            data: payload
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
        let service = GitHubService(signatureToken: signatureToken)

        let payload = "{}".data(using: .utf8)!

        let request = StubbedRequest(
            headers: [
                GitHubService.HTTPHeader.event.rawValue : "anything_really",
                GitHubService.HTTPHeader.signature.rawValue: signature(for: payload)
            ],
            data: payload
        )

        let result = service.handleEvent(from: request).first()

        expect(result?.error) == .unknown
    }

    func test_handling_untrustworthy_payload() {
        let service = GitHubService(signatureToken: signatureToken)

        let request = StubbedRequest(
            headers: [GitHubService.HTTPHeader.event.rawValue : "anything_really"],
            data: nil
        )

        let result = service.handleEvent(from: request).first()

        expect(result?.error) == .untrustworthy
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
            using scheduler: QueueScheduler
        ) -> SignalProducer<T, AnyError> where T: Decodable {
            switch data {
            case let .some(data):
                let decoder = JSONDecoder()
                do {
                    return SignalProducer(value: try decoder.decode(T.self, from: data))
                } catch {
                    return SignalProducer(error: AnyError(DecodeError.invalid))
                }
            case .none:
                return SignalProducer(error: AnyError(DecodeError.invalid))
            }
        }
    }
}
