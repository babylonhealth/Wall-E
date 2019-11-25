import XCTest
import Nimble
import ReactiveSwift
import Result
@testable import Bot

class DispatchServiceTests: XCTestCase {
    func test_multiple_pull_requests_with_different_target_branches() {

        let pullRequests = (1...3)
            .map {
                PullRequestMetadata.stub(number: $0, baseRef: "branch\($0)", labels: [LabelFixture.integrationLabel])
                    .with(mergeState: .clean)
            }

        perform(
            stubs: [
                .getPullRequests { pullRequests.map { $0.reference } },
                .getPullRequest { _ in pullRequests[0] },
                .postComment { _, _ in },
                .getPullRequest { _ in pullRequests[1] },
                .postComment { _, _ in },
                .getPullRequest { _ in pullRequests[2] },
                .postComment { _, _ in },
                .mergePullRequest { _ in },
                .deleteBranch { _ in },
                .mergePullRequest { _ in },
                .deleteBranch { _ in },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in
                scheduler.advance()
            },
            assert: {
                expect($0) == [
                    .created(branch: "branch1"),
                    .created(branch: "branch2"),
                    .created(branch: "branch3"),

                    .state(branch: "branch1", .stub(status: .starting)),
                    .state(branch: "branch2", .stub(status: .starting)),
                    .state(branch: "branch3", .stub(status: .starting)),

                    .state(branch: "branch1", .stub(status: .ready, pullRequests: [pullRequests[0].reference])),
                    .state(branch: "branch2", .stub(status: .ready, pullRequests: [pullRequests[1].reference])),
                    .state(branch: "branch3", .stub(status: .ready, pullRequests: [pullRequests[2].reference])),

                    .state(branch: "branch1", .stub(status: .integrating(pullRequests[0]))),
                    .state(branch: "branch2", .stub(status: .integrating(pullRequests[1]))),
                    .state(branch: "branch3", .stub(status: .integrating(pullRequests[2]))),

                    .state(branch: "branch1", .stub(status: .ready)),
                    .state(branch: "branch2", .stub(status: .ready)),
                    .state(branch: "branch3", .stub(status: .ready)),

                    .state(branch: "branch1", .stub(status: .idle)),
                    .destroyed(branch: "branch1"),

                    .state(branch: "branch2", .stub(status: .idle)),
                    .destroyed(branch: "branch2"),

                    .state(branch: "branch3", .stub(status: .idle)),
                    .destroyed(branch: "branch3")
                ]
            }
        )
    }

    private func checkComment(_ expectedPRNumber: UInt, _ expectedMessage: String) -> (String, PullRequest) -> Void {
        return { message, pullRequest in
            expect(pullRequest.number) == expectedPRNumber
            expect(message) == expectedMessage
        }
    }

    private func checkReturnPR(_ prToReturn: PullRequestMetadata) -> (UInt) -> PullRequestMetadata {
        return { number in
            expect(number) == prToReturn.reference.number
            return prToReturn
        }
    }

    private func checkPRNumber(_ expectedNumber: UInt) -> (PullRequest) -> Void {
        return { pullRequest in
            expect(pullRequest.number) == expectedNumber
        }
    }

    private func checkBranch(_ expectedBranch: PullRequest.Branch) -> (PullRequest.Branch) -> Void {
        return { branch in
            expect(branch.ref) == expectedBranch.ref
        }
    }

    func test_adding_new_pull_requests_during_integration() {
        let (developBranch, releaseBranch) = ("develop", "release/app/1.2.3")

        let dev1 = PullRequestMetadata.stub(number: 1, headRef: MergeServiceFixture.defaultBranch, baseRef: developBranch, labels: [LabelFixture.integrationLabel], mergeState: .behind)
        let dev2 = PullRequestMetadata.stub(number: 2, baseRef: developBranch, labels: [LabelFixture.integrationLabel], mergeState: .clean)
        let rel3 = PullRequestMetadata.stub(number: 3, baseRef: releaseBranch, labels: [LabelFixture.integrationLabel], mergeState: .clean)

        perform(
            stubs: [
                .getPullRequests { [dev1.reference] },
                .getPullRequest(checkReturnPR(dev1)),
                .postComment(checkComment(1, "Your pull request was accepted and is going to be handled right away 🏎")),
                .mergeIntoBranch { head, base in
                    expect(head.ref) == MergeServiceFixture.defaultBranch
                    expect(base.ref) == developBranch
                    return .success
                },

                .postComment(checkComment(2, "Your pull request was accepted and it's currently `#1` in the queue, hold tight ⏳")),

                .getPullRequest(checkReturnPR(rel3)),
                .postComment(checkComment(3, "Your pull request was accepted and is going to be handled right away 🏎")),
                .mergePullRequest(checkPRNumber(3)),
                .deleteBranch(checkBranch(rel3.reference.source)),

                .getPullRequest(checkReturnPR(dev1.with(mergeState: .clean))),
                .getCommitStatus { pullRequest in
                    expect(pullRequest.number) == 1
                    return CommitState.stub(states: [.success])
                },

                .mergePullRequest(checkPRNumber(1)),
                .deleteBranch(checkBranch(dev1.reference.source)),
                .getPullRequest(checkReturnPR(dev2)),
                .mergePullRequest(checkPRNumber(2)),
                .deleteBranch(checkBranch(dev2.reference.source)),
            ],
            when: { service, scheduler in

                scheduler.advance()

                service.eventsObserver.send(value: .pullRequest(
                    .init(action: .synchronize, pullRequestMetadata: dev1.with(mergeState: .blocked)))
                )

                scheduler.advance()

                service.eventsObserver.send(value: .pullRequest(
                    .init(action: .labeled, pullRequestMetadata: dev2))
                )

                scheduler.advance()

                service.eventsObserver.send(value: .pullRequest(
                    .init(action: .labeled, pullRequestMetadata: rel3))
                )

                scheduler.advance()

                service.sendStatusEvent(state: .success)

                scheduler.advance(by: .seconds(60))
            },
            assert: {
                expect($0) == [
                    .created(branch: developBranch),
                    .state(branch: developBranch, .stub(status: .starting)),
                    .state(branch: developBranch, .stub(status: .ready, pullRequests: [dev1.reference])),
                    .state(branch: developBranch, .stub(status: .integrating(dev1))),
                    .state(branch: developBranch, .stub(status: .runningStatusChecks(dev1.with(mergeState: .blocked)))),
                    .state(branch: developBranch, .stub(status: .runningStatusChecks(dev1.with(mergeState: .blocked)), pullRequests: [dev2.reference])),

                    .created(branch: releaseBranch),
                    .state(branch: releaseBranch, .stub(status: .starting)),
                    .state(branch: releaseBranch, .stub(status: .ready, pullRequests: [rel3.reference])),
                    .state(branch: releaseBranch, .stub(status: .integrating(rel3))),
                    .state(branch: releaseBranch, .stub(status: .ready)),
                    .state(branch: releaseBranch, .stub(status: .idle)),
                    .destroyed(branch: releaseBranch),

                    .state(branch: developBranch, .stub(status: .integrating(dev1.with(mergeState: .clean)), pullRequests: [dev2.reference])),
                    .state(branch: developBranch, .stub(status: .ready, pullRequests: [dev2.reference])),
                    .state(branch: developBranch, .stub(status: .integrating(dev2))),
                    .state(branch: developBranch, .stub(status: .ready)),
                    .state(branch: developBranch, .stub(status: .idle)),
                    .destroyed(branch: developBranch)
                ]
            }
        )
    }

    // MARK: - Helpers

    private var dispatchService: DispatchService?

    private func perform(
        requiresAllStatusChecks: Bool = false,
        stubs: [MockGitHubAPI.Stubs],
        when: (MockGitHubEventsService, TestScheduler) -> Void,
        assert: ([DispatchServiceEvent]) -> Void
    ) {

        let scheduler = TestScheduler()
        let gitHubAPI = MockGitHubAPI(stubs: stubs)
        let gitHubEvents = MockGitHubEventsService()

        let dispatchServiceContext = DispatchServiceContext(
            requiresAllStatusChecks: requiresAllStatusChecks,
            gitHubAPI: gitHubAPI,
            gitHubEvents: gitHubEvents,
            scheduler: scheduler
        )

        when(gitHubEvents, scheduler)

        assert(dispatchServiceContext.events)

        expect(gitHubAPI.assert()) == true

        self.dispatchService = nil
    }
}
