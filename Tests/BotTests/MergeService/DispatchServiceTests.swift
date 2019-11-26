import XCTest
import Nimble
import ReactiveSwift
import Result
@testable import Bot

class DispatchServiceTests: XCTestCase {
    func test_multiple_pull_requests_with_different_target_branches() {

        let pullRequests = (1...3).map {
            PullRequestMetadata.stub(number: $0, baseRef: "branch\($0)", labels: [LabelFixture.integrationLabel])
                .with(mergeState: .clean)
        }
        func returnPR() -> (UInt) -> PullRequestMetadata {
            return { number in pullRequests[Int(number-1)] }
        }

        perform(
            stubs: [
                .getPullRequests { pullRequests.map { $0.reference } },
                .getPullRequest(returnPR()),
                .postComment { _, _ in },
                .getPullRequest(returnPR()),
                .postComment { _, _ in },
                .getPullRequest(returnPR()),
                .postComment { _, _ in },
                .mergePullRequest { _ in },
                .deleteBranch { _ in },
                .mergePullRequest { _ in },
                .deleteBranch { _ in },
                .mergePullRequest { _ in },
                .deleteBranch { _ in },
            ],
            when: { service, scheduler in
                scheduler.advance()
            },
            assert: { events in
                let perBranchEvents = Dictionary(grouping: events) { $0.branch }
                expect(perBranchEvents.count) == 3
                for (branch, events) in perBranchEvents {
                    let filteredPRs = pullRequests.filter { $0.reference.target.ref == branch }
                    expect(filteredPRs.count) == 1
                    let prForBranch = filteredPRs.first!
                    expect(events) == [
                        .created(branch: branch),
                        .state(.stub(targetBranch: branch, status: .starting)),
                        .state(.stub(targetBranch: branch, status: .ready, pullRequests: [prForBranch.reference])),
                        .state(.stub(targetBranch: branch, status: .integrating(prForBranch))),
                        .state(.stub(targetBranch: branch, status: .ready)),
                        .state(.stub(targetBranch: branch, status: .idle)),
                        .destroyed(branch: branch),
                    ]
                }
            }
        )
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

                .postComment(checkComment(2, "Your pull request was accepted and it's currently `#1` in the `develop` queue, hold tight ⏳")),

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

                service.sendPullRequestEvent(action: .synchronize, pullRequestMetadata: dev1.with(mergeState: .blocked))

                scheduler.advance()

                service.sendPullRequestEvent(action: .labeled, pullRequestMetadata: dev2)

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
                    .state(.stub(targetBranch: developBranch, status: .starting)),
                    .state(.stub(targetBranch: developBranch, status: .ready, pullRequests: [dev1.reference])),
                    .state(.stub(targetBranch: developBranch, status: .integrating(dev1))),
                    .state(.stub(targetBranch: developBranch, status: .runningStatusChecks(dev1.with(mergeState: .blocked)))),
                    .state(.stub(targetBranch: developBranch, status: .runningStatusChecks(dev1.with(mergeState: .blocked)), pullRequests: [dev2.reference])),

                    .created(branch: releaseBranch),
                    .state(.stub(targetBranch: releaseBranch, status: .starting)),
                    .state(.stub(targetBranch: releaseBranch, status: .ready, pullRequests: [rel3.reference])),
                    .state(.stub(targetBranch: releaseBranch, status: .integrating(rel3))),
                    .state(.stub(targetBranch: releaseBranch, status: .ready)),
                    .state(.stub(targetBranch: releaseBranch, status: .idle)),
                    .destroyed(branch: releaseBranch),

                    .state(.stub(targetBranch: developBranch, status: .integrating(dev1.with(mergeState: .clean)), pullRequests: [dev2.reference])),
                    .state(.stub(targetBranch: developBranch, status: .ready, pullRequests: [dev2.reference])),
                    .state(.stub(targetBranch: developBranch, status: .integrating(dev2))),
                    .state(.stub(targetBranch: developBranch, status: .ready)),
                    .state(.stub(targetBranch: developBranch, status: .idle)),
                    .destroyed(branch: developBranch)
                ]
            }
        )
    }

    func test_json_queue_description() throws {
        let (branch1, branch2) = ("branch1", "branch2")
        let pr1 = PullRequestMetadata.stub(number: 1, headRef: MergeServiceFixture.defaultBranch, baseRef: branch1, labels: [LabelFixture.integrationLabel], mergeState: .behind)
        let pr2 = PullRequestMetadata.stub(number: 2, baseRef: branch1, labels: [LabelFixture.integrationLabel], mergeState: .clean)
        let pr3 = PullRequestMetadata.stub(number: 3, baseRef: branch2, labels: [LabelFixture.integrationLabel], mergeState: .behind)

        let stubs: [MockGitHubAPI.Stubs] = [
            .getPullRequests { [pr1.reference] },
            .getPullRequest(checkReturnPR(pr1)),
            .postComment(checkComment(1, "Your pull request was accepted and is going to be handled right away 🏎")),
            .mergeIntoBranch { _, _ in .success },
            .postComment(checkComment(2, "Your pull request was accepted and it's currently `#1` in the `branch1` queue, hold tight ⏳")),
            .getPullRequest(checkReturnPR(pr3)),
            .postComment(checkComment(3, "Your pull request was accepted and is going to be handled right away 🏎")),
            .mergeIntoBranch { _, _ in .success },
        ]

        let scheduler = TestScheduler()
        let gitHubAPI = MockGitHubAPI(stubs: stubs)
        let gitHubEvents = MockGitHubEventsService()

        let dispatchServiceContext = DispatchServiceContext(
            requiresAllStatusChecks: true,
            gitHubAPI: gitHubAPI,
            gitHubEvents: gitHubEvents,
            scheduler: scheduler
        )

        expect(dispatchServiceContext.dispatchService.queueStates) == []

        scheduler.advance()
        gitHubEvents.sendPullRequestEvent(action: .labeled, pullRequestMetadata: pr2)
        scheduler.advance()
        gitHubEvents.sendPullRequestEvent(action: .labeled, pullRequestMetadata: pr3)
        scheduler.advance()

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(dispatchServiceContext.dispatchService.queueStates)
        let json = String(data: data, encoding: .utf8)
        expect(json) == DispatchServiceQueueStates
    }

    // MARK: - Helpers

    private func checkComment(_ expectedPRNumber: UInt, _ expectedMessage: String, file: FileString = #file, line: UInt = #line) -> (String, PullRequest) -> Void {
        return { message, pullRequest in
            expect(pullRequest.number, file: file, line: line) == expectedPRNumber
            expect(message, file: file, line: line) == expectedMessage
        }
    }

    private func checkReturnPR(_ prToReturn: PullRequestMetadata, file: FileString = #file, line: UInt = #line) -> (UInt) -> PullRequestMetadata {
        return { number in
            expect(number, file: file, line: line) == prToReturn.reference.number
            return prToReturn
        }
    }

    private func checkPRNumber(_ expectedNumber: UInt, file: FileString = #file, line: UInt = #line) -> (PullRequest) -> Void {
        return { pullRequest in
            expect(pullRequest.number, file: file, line: line) == expectedNumber
        }
    }

    private func checkBranch(_ expectedBranch: PullRequest.Branch, file: FileString = #file, line: UInt = #line) -> (PullRequest.Branch) -> Void {
        return { branch in
            expect(branch.ref, file: file, line: line) == expectedBranch.ref
        }
    }

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
    }
    
}
