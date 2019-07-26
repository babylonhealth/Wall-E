import XCTest
import Nimble
import ReactiveSwift
import Result
@testable import Bot

struct MockLogger: LoggerProtocol {
    func log(_ message: String) {
        print(message)
    }
}

let IntegrationLabel = PullRequest.Label(name: "Please Merge 🙏")

let defaultBranch = "some-branch"

let defaultTarget = PullRequestMetadata.stub(
    number: 1,
    headRef: defaultBranch,
    labels: [IntegrationLabel],
    mergeState: .behind
)

let defaultStatusChecksTimeout: TimeInterval = 60.minutes

class MergeServiceTests: XCTestCase {

    func test_empty_list_of_pull_requests_should_do_nothing() {
        perform(
            stubs: [
                .getPullRequests { [] }
            ],
            when: { _, scheduler in
                scheduler.advance()
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )
    }

    func test_no_pull_requests_with_integration_label() {
        perform(
            stubs: [
                .getPullRequests { [
                    PullRequestMetadata.stub(number: 1).reference,
                    PullRequestMetadata.stub(number: 2).reference
                    ]
                }
            ],
            when: { _, scheduler in
                scheduler.advance()
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )

    }

    func test_pull_request_with_integration_label_and_ready_to_merge() {
        perform(
            stubs: [
                .getPullRequests { [defaultTarget.reference] },
                .getPullRequest { _ in defaultTarget.with(mergeState: .clean) },
                .postComment { _, _ in },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in
                scheduler.advance()
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .ready, pullRequests: [defaultTarget.reference]),
                    makeState(status: .integrating(defaultTarget.with(mergeState: .clean)), pullRequests: []),
                    makeState(status: .ready, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )
    }

    func test_multiple_pull_requests_with_integration_label_and_ready_to_merge() {

        let pullRequests = (1...3)
            .map {
                PullRequestMetadata.stub(number: $0, labels: [IntegrationLabel])
                    .with(mergeState: .clean)
            }

        perform(
            stubs: [
                .getPullRequests { pullRequests.map { $0.reference } },
                .getPullRequest { _ in pullRequests[0] },
                .postComment { _, _ in },
                .postComment { _, _ in },
                .postComment { _, _ in },
                .mergePullRequest { _ in },
                .deleteBranch { _ in },
                .getPullRequest { _ in pullRequests[1] },
                .mergePullRequest { _ in },
                .deleteBranch { _ in },
                .getPullRequest { _ in pullRequests[2] },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in
                scheduler.advance()
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .ready, pullRequests: pullRequests.map { $0.reference }),
                    makeState(status: .integrating(pullRequests[0]), pullRequests: pullRequests.map { $0.reference }.suffix(2).asArray),
                    makeState(status: .ready, pullRequests: pullRequests.map { $0.reference }.suffix(2).asArray),
                    makeState(status: .integrating(pullRequests[1]), pullRequests: pullRequests.map { $0.reference }.suffix(1).asArray),
                    makeState(status: .ready, pullRequests: pullRequests.map { $0.reference }.suffix(1).asArray),
                    makeState(status: .integrating(pullRequests[2]), pullRequests: []),
                    makeState(status: .ready, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )
    }

    func test_pull_request_with_integration_label_and_conflicts() {

        let target = defaultTarget.with(mergeState: .dirty)

        perform(
            stubs: [
                .getPullRequests { [target.reference] },
                .getPullRequest { _ in target },
                .postComment { _, _ in },
                .postComment { _, _ in },
                .removeLabel { _, _ in }
            ],
            when: { service, scheduler in
                scheduler.advance()
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .ready, pullRequests: [target.reference]),
                    makeState(status: .integrating(target), pullRequests: []),
                    makeState(status: .integrationFailed(target, .conflicts), pullRequests: []),
                    makeState(status: .ready, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )
    }

    func test_pull_request_with_integration_label_and_behind_target_branch() {
        perform(
            stubs: [
                .getPullRequests { [defaultTarget.reference] },
                .getPullRequest { _ in defaultTarget },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success },
                .getPullRequest { _ in defaultTarget.with(mergeState: .clean) },
                .getCommitStatus { _ in CommitState(state: .success, statuses: []) },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in

                scheduler.advance()

                service.pullRequestDidChange(metadata: defaultTarget.with(mergeState: .blocked), action: .synchronize)

                scheduler.advance()

                service.statusChecksDidChange(
                    change: StatusChange(
                        sha: "abcdef",
                        context: "",
                        description: "N/A",
                        state: .success,
                        branches: [.init(name: defaultBranch)]
                    )
                )

                scheduler.advance(by: .seconds(60))
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .ready, pullRequests: [defaultTarget.reference]),
                    makeState(status: .integrating(defaultTarget), pullRequests: []),
                    makeState(status: .runningStatusChecks(defaultTarget.with(mergeState: .blocked)), pullRequests: []),
                    makeState(status: .integrating(defaultTarget.with(mergeState: .clean)), pullRequests: []),
                    makeState(status: .ready, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )
    }

    func test_pull_request_blocked_with_successful_status() {
        perform(
            stubs: [
                .getPullRequests { [defaultTarget.reference] },
                .getPullRequest { _ in defaultTarget.with(mergeState: .blocked) },
                .postComment { _, _ in },
                .getCommitStatus { _ in CommitState(state: .success, statuses: []) },
                .getPullRequest { _ in defaultTarget.with(mergeState: .clean) },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in
                scheduler.advance()

                service.statusChecksDidChange(
                    change: StatusChange(
                        sha: "abcdef",
                        context: "",
                        description: "N/A",
                        state: .success,
                        branches: [.init(name: defaultBranch)]
                    )
                )

                scheduler.advance()
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .ready, pullRequests: [defaultTarget.reference]),
                    makeState(status: .integrating(defaultTarget.with(mergeState: .blocked)), pullRequests: []),
                    makeState(status: .integrating(defaultTarget.with(mergeState: .clean)), pullRequests: []),
                    makeState(status: .ready, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )
    }

    func test_resuming_after_labelling_a_pull_request() {

        let target = PullRequestMetadata.stub(number: 1, headRef: defaultBranch, labels: [], mergeState: .clean)
        let targetLabeled = target.with(labels: [IntegrationLabel])

        perform(
            stubs: [
                .getPullRequests { [target.reference] },
                .getPullRequest { _ in targetLabeled },
                .postComment { _, _ in },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in
                scheduler.advance()
                service.pullRequestDidChange(metadata: targetLabeled, action: .labeled)
                scheduler.advance()
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .idle, pullRequests: []),
                    makeState(status: .ready, pullRequests: [targetLabeled.reference]),
                    makeState(status: .integrating(targetLabeled), pullRequests: []),
                    makeState(status: .ready, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
        }
        )
    }

    func test_adding_a_new_pull_request_while_running_an_integrating() {

        let first = defaultTarget.with(mergeState: .behind)
        let second = PullRequestMetadata.stub(number: 2, labels: [IntegrationLabel], mergeState: .clean)

        perform(
            stubs: [
                .getPullRequests { [first.reference] },
                .getPullRequest { _ in first },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success },
                .postComment { _, _ in },
                .getPullRequest { _ in first.with(mergeState: .clean) },
                .getCommitStatus { _ in CommitState(state: .success, statuses: []) },
                .mergePullRequest { _ in },
                .deleteBranch { _ in },
                .getPullRequest { _ in second },
                .mergePullRequest { _ in },
                .deleteBranch { _ in },
            ],
            when: { service, scheduler in

                scheduler.advance()

                service.pullRequestDidChange(metadata: first.with(mergeState: .blocked), action: .synchronize)

                scheduler.advance()

                service.pullRequestDidChange(metadata: second, action: .labeled)

                scheduler.advance()

                service.statusChecksDidChange(
                    change: StatusChange(
                        sha: "abcdef",
                        context: "",
                        description: "N/A",
                        state: .success,
                        branches: [.init(name: defaultBranch)]
                    )
                )

                scheduler.advance(by: .seconds(60))
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .ready, pullRequests: [first.reference]),
                    makeState(status: .integrating(first), pullRequests: []),
                    makeState(status: .runningStatusChecks(first.with(mergeState: .blocked)), pullRequests: []),
                    makeState(status: .runningStatusChecks(first.with(mergeState: .blocked)), pullRequests: [second.reference]),
                    makeState(status: .integrating(first.with(mergeState: .clean)), pullRequests: [second.reference]),
                    makeState(status: .ready, pullRequests: [second.reference]),
                    makeState(status: .integrating(second), pullRequests: []),
                    makeState(status: .ready, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )
    }

    func test_closing_pull_request_during_integration() {
        perform(
            stubs: [
                .getPullRequests { [defaultTarget.reference] },
                .getPullRequest { _ in defaultTarget },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success }
            ],
            when: { service, scheduler in
                scheduler.advance()

                service.pullRequestDidChange(metadata: defaultTarget.with(mergeState: .blocked), action: .synchronize)

                scheduler.advance()

                service.pullRequestDidChange(metadata: defaultTarget, action: .closed)

                scheduler.advance()
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .ready, pullRequests: [defaultTarget.reference]),
                    makeState(status: .integrating(defaultTarget), pullRequests: []),
                    makeState(status: .runningStatusChecks(defaultTarget.with(mergeState: .blocked)), pullRequests: []),
                    makeState(status: .ready, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )
    }

    func test_removing_the_integration_label_during_integration() {
        perform(
            stubs: [
                .getPullRequests { [defaultTarget.reference] },
                .getPullRequest { _ in defaultTarget },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success }
            ],
            when: { service, scheduler in
                scheduler.advance()

                service.pullRequestDidChange(metadata: defaultTarget.with(mergeState: .blocked), action: .synchronize)

                scheduler.advance()

                service.pullRequestDidChange(metadata: defaultTarget.with(labels: []), action: .unlabeled)

                scheduler.advance()
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .ready, pullRequests: [defaultTarget.reference]),
                    makeState(status: .integrating(defaultTarget), pullRequests: []),
                    makeState(status: .runningStatusChecks(defaultTarget.with(mergeState: .blocked)), pullRequests: []),
                    makeState(status: .ready, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )
    }

    func test_pull_request_with_status_checks_failing() {
        perform(
            stubs: [
                .getPullRequests { [defaultTarget.reference] },
                .getPullRequest { _ in defaultTarget },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success },
                .getPullRequest { _ in defaultTarget.with(mergeState: .blocked) },
                .getCommitStatus { _ in CommitState(state: .failure, statuses: []) },
                .postComment { _, _ in },
                .removeLabel { _, _ in }
            ],
            when: { service, scheduler in
                scheduler.advance()

                service.pullRequestDidChange(metadata: defaultTarget.with(mergeState: .blocked), action: .synchronize)

                scheduler.advance()

                service.statusChecksDidChange(
                    change: StatusChange(
                        sha: "abcdef",
                        context: "",
                        description: "N/A",
                        state: .failure,
                        branches: [.init(name: defaultBranch)]
                    )
                )

                scheduler.advance(by: .seconds(60))
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .ready, pullRequests: [defaultTarget.reference]),
                    makeState(status: .integrating(defaultTarget), pullRequests: []),
                    makeState(status: .runningStatusChecks(defaultTarget.with(mergeState: .blocked)), pullRequests: []),
                    makeState(status: .integrationFailed(defaultTarget.with(mergeState: .blocked), .checksFailing), pullRequests: []),
                    makeState(status: .ready, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )
    }

    func test_pull_request_with_multiple_status_checks() {
        perform(
            stubs: [
                .getPullRequests { [defaultTarget.reference] },
                .getPullRequest { _ in defaultTarget },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success },
                .getPullRequest { _ in defaultTarget.with(mergeState: .blocked) },
                .getCommitStatus { _ in CommitState(state: .pending, statuses: []) },
                .getPullRequest { _ in defaultTarget.with(mergeState: .blocked) },
                .getCommitStatus { _ in CommitState(state: .pending, statuses: []) },
                .getPullRequest { _ in defaultTarget.with(mergeState: .clean) },
                .getCommitStatus { _ in CommitState(state: .success, statuses: []) },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in
                scheduler.advance()

                service.pullRequestDidChange(metadata: defaultTarget.with(mergeState: .blocked), action: .synchronize)

                scheduler.advance()

                for _ in 1...3 {

                    service.statusChecksDidChange(
                        change: StatusChange(
                            sha: "abcdef",
                            context: "",
                            description: "N/A",
                            state: .success,
                            branches: [StatusChange.Branch(name: defaultBranch)]
                        )
                    )

                    scheduler.advance(by: .seconds(60))
                }
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .ready, pullRequests: [defaultTarget.reference]),
                    makeState(status: .integrating(defaultTarget), pullRequests: []),
                    makeState(status: .runningStatusChecks(defaultTarget.with(mergeState: .blocked)), pullRequests: []),
                    makeState(status: .integrating(defaultTarget.with(mergeState: .clean)), pullRequests: []),
                    makeState(status: .ready, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )
    }

    func test_pull_request_fails_integration_after_timeout() {

        perform(
            stubs: [
                .getPullRequests { [defaultTarget.reference] },
                .getPullRequest { _ in defaultTarget },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success },
                .postComment { _, _ in },
                .removeLabel { _, _ in }
                ],
            when: { service, scheduler in
                scheduler.advance()

                service.pullRequestDidChange(metadata: defaultTarget.with(mergeState: .blocked), action: .synchronize)

                // 1.5 ensures we trigger the timeout
                scheduler.advance(by: .minutes(1.5 * defaultStatusChecksTimeout))
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .ready, pullRequests: [defaultTarget.reference]),
                    makeState(status: .integrating(defaultTarget), pullRequests: []),
                    makeState(status: .runningStatusChecks(defaultTarget.with(mergeState: .blocked)), pullRequests: []),
                    makeState(status: .integrationFailed(defaultTarget.with(mergeState: .blocked), .checksFailing), pullRequests: []),
                    makeState(status: .ready, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )
    }

    func test_pull_request_with_an_initial_unknown_state_with_recover() {
        perform(
            stubs: [
                .getPullRequests { [defaultTarget.reference] },
                .getPullRequest { _ in defaultTarget.with(mergeState: .unknown) },
                .postComment { _, _ in },
                .getPullRequest { _ in defaultTarget.with(mergeState: .unknown) },
                .getPullRequest { _ in defaultTarget.with(mergeState: .unknown) },
                .getPullRequest { _ in defaultTarget.with(mergeState: .clean) },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in
                scheduler.advance(by: .seconds(60))
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .ready, pullRequests: [defaultTarget.reference]),
                    makeState(status: .integrating(defaultTarget.with(mergeState: .unknown)), pullRequests: []),
                    makeState(status: .integrating(defaultTarget.with(mergeState: .clean)), pullRequests: []),
                    makeState(status: .ready, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )
    }

    func test_pull_request_with_an_initial_unknown_state_without_recover() {
        perform(
            stubs: [
                .getPullRequests { [defaultTarget.reference] },
                .getPullRequest { _ in defaultTarget.with(mergeState: .unknown) },
                .postComment { _, _ in },
                .getPullRequest { _ in defaultTarget.with(mergeState: .unknown) },
                .getPullRequest { _ in defaultTarget.with(mergeState: .unknown) },
                .getPullRequest { _ in defaultTarget.with(mergeState: .unknown) },
                .getPullRequest { _ in defaultTarget.with(mergeState: .unknown) },
                .getPullRequest { _ in defaultTarget.with(mergeState: .unknown) },
                .postComment { _, _ in },
                .removeLabel { _, _ in }
            ],
            when: { service, scheduler in
                scheduler.advance(by: .seconds(5 * 30))
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .ready, pullRequests: [defaultTarget.reference]),
                    makeState(status: .integrating(defaultTarget.with(mergeState: .unknown)), pullRequests: []),
                    makeState(status: .integrationFailed(defaultTarget.with(mergeState: .unknown), .unknown), pullRequests: []),
                    makeState(status: .ready, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )
    }

    func test_excluding_pull_request_in_the_queue() {

        let first = defaultTarget.with(mergeState: .behind)
        let second = PullRequestMetadata.stub(number: 2, labels: [IntegrationLabel], mergeState: .clean)

        perform(
            stubs: [
                .getPullRequests { [first, second].map { $0.reference} },
                .getPullRequest { _ in first },
                .postComment { _, _ in },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success },
                .getPullRequest { _ in first.with(mergeState: .clean) },
                .getCommitStatus { _ in CommitState(state: .success, statuses: []) },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in

                scheduler.advance()

                service.pullRequestDidChange(metadata: first.with(mergeState: .blocked), action: .synchronize)

                scheduler.advance()

                service.pullRequestDidChange(metadata: second.with(labels: []), action: .unlabeled)

                scheduler.advance()

                service.statusChecksDidChange(
                    change: StatusChange(
                        sha: "abcdef",
                        context: "",
                        description: "N/A",
                        state: .failure,
                        branches: [.init(name: defaultBranch)]
                    )
                )

                scheduler.advance(by: .seconds(60))
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .ready, pullRequests: [first, second].map { $0.reference}),
                    makeState(status: .integrating(first), pullRequests: [second.reference]),
                    makeState(status: .runningStatusChecks(first.with(mergeState: .blocked)), pullRequests: [second.reference]),
                    makeState(status: .runningStatusChecks(first.with(mergeState: .blocked)), pullRequests: []),
                    makeState(status: .integrating(first.with(mergeState: .clean)), pullRequests: []),
                    makeState(status: .ready, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )
    }

    func test_pull_requests_receive_feedback_when_accepted() {

        let pullRequests = (1...3)
            .map {
                PullRequestMetadata.stub(number: $0, labels: [IntegrationLabel])
                    .with(mergeState: .clean)
        }

        perform(
            stubs: [
                .getPullRequests { pullRequests.map { $0.reference } },
                .getPullRequest { _ in pullRequests[0] },
                .postComment { message, pullRequest in
                    expect(message) == "Your pull request was accepted and is going to be handled right away 🏎"
                    expect(pullRequest.number) == 1
                },
                .postComment { message, pullRequest in
                    expect(message) == "Your pull request was accepted and it's currently `#2` in the queue, hold tight ⏳"
                    expect(pullRequest.number) == 2
                },
                .postComment { message, pullRequest in
                    expect(message) == "Your pull request was accepted and it's currently `#3` in the queue, hold tight ⏳"
                    expect(pullRequest.number) == 3
                },
                .mergePullRequest { _ in },
                .deleteBranch { _ in },
                .getPullRequest { _ in pullRequests[1] },
                .mergePullRequest { _ in },
                .deleteBranch { _ in },
                .getPullRequest { _ in pullRequests[2] },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in
                scheduler.advance()
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .ready, pullRequests: pullRequests.map { $0.reference }),
                    makeState(status: .integrating(pullRequests[0]), pullRequests: pullRequests.map { $0.reference }.suffix(2).asArray),
                    makeState(status: .ready, pullRequests: pullRequests.map { $0.reference }.suffix(2).asArray),
                    makeState(status: .integrating(pullRequests[1]), pullRequests: pullRequests.map { $0.reference }.suffix(1).asArray),
                    makeState(status: .ready, pullRequests: pullRequests.map { $0.reference }.suffix(1).asArray),
                    makeState(status: .integrating(pullRequests[2]), pullRequests: []),
                    makeState(status: .ready, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )
    }

    func test_pull_request_does_not_fail_prematurely_if_checks_complete_before_adding_the_following_checks() {

        var expectedPullRequest = defaultTarget.with(mergeState: .blocked)
        var expectedCommitStatus = CommitState(state: .success, statuses: [])

        perform(
            stubs: [
                .getPullRequests { [defaultTarget.reference] },
                .getPullRequest { _ in defaultTarget },
                .postComment { _, _  in },
                .mergeIntoBranch { _, _ in .success },
                .getPullRequest { _ in expectedPullRequest },
                .getCommitStatus { _ in expectedCommitStatus },
                .getPullRequest { _ in expectedPullRequest },
                .getCommitStatus { _ in expectedCommitStatus },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in
                scheduler.advance()

                service.pullRequestDidChange(metadata: defaultTarget.with(mergeState: .blocked), action: .synchronize)

                scheduler.advance()

                service.statusChecksDidChange(
                    change: StatusChange(
                        sha: "abcdef",
                        context: "",
                        description: "N/A",
                        state: .success,
                        branches: [.init(name: defaultBranch)]
                    )
                )

                scheduler.advance(by: .seconds(30))

                // Simulate a new check being added

                expectedCommitStatus = CommitState(state: .pending, statuses: [])

                scheduler.advance(by: .seconds(30))

                // Simulate all checks being successful

                service.statusChecksDidChange(
                    change: StatusChange(
                        sha: "abcdef",
                        context: "",
                        description: "N/A",
                        state: .success,
                        branches: [.init(name: defaultBranch)]
                    )
                )

                expectedPullRequest = defaultTarget.with(mergeState: .clean)
                expectedCommitStatus = CommitState(state: .success, statuses: [])

                scheduler.advance(by: .seconds(60))
            },
            assert: {
                expect($0) == [
                    makeState(status: .starting, pullRequests: []),
                    makeState(status: .ready, pullRequests: [defaultTarget.reference]),
                    makeState(status: .integrating(defaultTarget), pullRequests: []),
                    makeState(status: .runningStatusChecks(defaultTarget.with(mergeState: .blocked)), pullRequests: []),
                    makeState(status: .integrating(defaultTarget.with(mergeState: .clean)), pullRequests: []),
                    makeState(status: .ready, pullRequests: []),
                    makeState(status: .idle, pullRequests: [])
                ]
            }
        )
    }

    // MARK: - Helpers

    private func perform(
        stubs: [MockGitHubAPI.Stubs],
        when: (MergeService, TestScheduler) -> Void,
        assert: ([MergeService.State]) -> Void
        ) {

        let scheduler = TestScheduler()
        let github2 = MockGitHubAPI(stubs: stubs)
        let service = MergeService(integrationLabel: IntegrationLabel, logger: MockLogger(), github: github2, scheduler: scheduler)

        var states: [MergeService.State] = []

        service.state.producer.observe(on: scheduler).startWithValues { states.append($0) }

        when(service, scheduler)
        assert(states)

        expect(github2.assert()) == true
    }

    private func makeState(
        status: MergeService.State.Status,
        pullRequests: [PullRequest],
        statusChecksTimeout: TimeInterval = defaultStatusChecksTimeout
        ) -> MergeService.State {
        return MergeService.State(
            integrationLabel: IntegrationLabel,
            statusChecksTimeout: statusChecksTimeout,
            pullRequests: pullRequests,
            status: status
        )
    }
}

// MARK: - Debug helpers

extension PullRequestMetadata {

    fileprivate static func stub(
        number: UInt,
        headRef: String = "abcdef",
        labels: [PullRequest.Label] = [],
        mergeState: PullRequestMetadata.MergeState = .clean
    ) -> PullRequestMetadata {
        return PullRequestMetadata(
            reference: PullRequest(
                number: number,
                title: "Best Pull Request",
                author: .init(login: "John Doe"),
                source: .init(ref: headRef, sha: "abcdef"),
                target: .init(ref: "master", sha: "abc"),
                labels: labels
            ),
            isMerged: false,
            mergeState: mergeState
        )
    }

    fileprivate func with(mergeState: MergeState) -> PullRequestMetadata {
        return PullRequestMetadata(
            reference: PullRequest(
                number: reference.number,
                title: reference.title,
                author: reference.author,
                source: reference.source,
                target: reference.target,
                labels: reference.labels
            ),
            isMerged: isMerged,
            mergeState: mergeState
        )
    }

    fileprivate func with(labels: [PullRequest.Label]) -> PullRequestMetadata {
        return PullRequestMetadata(
            reference: PullRequest(
                number: reference.number,
                title: reference.title,
                author: reference.author,
                source: reference.source,
                target: reference.target,
                labels: labels
            ),
            isMerged: isMerged,
            mergeState: mergeState
        )
    }
}

extension PullRequest.Label {

    fileprivate static func stub(name: String) -> PullRequest.Label {
        return PullRequest.Label(name: name)
    }
}

extension ArraySlice {

    var asArray: [Element] {
        return Array(self)
    }
}

extension DispatchTimeInterval {

    static func minutes(_ value: Double) -> DispatchTimeInterval {
        return .seconds(Int(value) * 60)
    }
}
