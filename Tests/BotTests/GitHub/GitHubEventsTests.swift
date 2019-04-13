import XCTest
import Nimble
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

        let request = StubbedRequest(headers: ["X-GitHub-Event" : "pull_request"], body: pullRequestEvent)

        var observedEvent: Event? = nil

        service.events
            .observe(on: scheduler)
            .observeValues { event in observedEvent = event }

        let result = service.handleEvent(from: request)

        scheduler.advance()

        expect(result.error).to(beNil())
        expect(observedEvent) == Event.pullRequest(pullRequestEvent)
    }

    func test_handling_ping_event() {
        let service = GitHubService()
        let scheduler = TestScheduler()

        let request = StubbedRequest(headers: ["X-GitHub-Event" : "ping"], body: nil)

        var observedEvent: Event? = nil

        service.events
            .observe(on: scheduler)
            .observeValues { event in observedEvent = event }

        let result = service.handleEvent(from: request)

        scheduler.advance()

        expect(result.error).to(beNil())
        expect(observedEvent) == Event.ping
    }

    func test_handling_unknown_event() {
        let service = GitHubService()

        let request = StubbedRequest(headers: ["X-GitHub-Event" : "unknown"], body: nil)

        let result = service.handleEvent(from: request)

        expect(result.error) == .unknown
    }
}

extension GitHubEventsTests {
    fileprivate struct StubbedRequest: RequestProtocol {
        let headers: [String : String]
        let body: Any?

        func header(named name: String) -> String? {
            return headers[name]
        }

        func decodeBody<T>(_ type: T.Type) -> T? where T : Decodable {
            return body as? T
        }
    }
}
