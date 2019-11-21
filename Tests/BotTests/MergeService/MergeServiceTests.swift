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
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .idle)
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
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )

    }

    func test_pull_request_with_integration_label_and_ready_to_merge() {
        perform(
            stubs: [
                .getPullRequests { [MergeServiceFixture.defaultTarget.reference] },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .clean) },
                .postComment { _, _ in },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in
                scheduler.advance()
            },
            assert: {
                expect($0) == [
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: [MergeServiceFixture.defaultTarget.reference]),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget.with(mergeState: .clean))),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )
    }

    func test_multiple_pull_requests_with_integration_label_and_ready_to_merge() {

        let pullRequests = (1...3)
            .map {
                PullRequestMetadata.stub(number: $0, labels: [LabelFixture.integrationLabel])
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
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: pullRequests.map { $0.reference }),
                    MergeService.State.stub(status: .integrating(pullRequests[0]), pullRequests: pullRequests.map { $0.reference }.suffix(2).asArray),
                    MergeService.State.stub(status: .ready, pullRequests: pullRequests.map { $0.reference }.suffix(2).asArray),
                    MergeService.State.stub(status: .integrating(pullRequests[1]), pullRequests: pullRequests.map { $0.reference }.suffix(1).asArray),
                    MergeService.State.stub(status: .ready, pullRequests: pullRequests.map { $0.reference }.suffix(1).asArray),
                    MergeService.State.stub(status: .integrating(pullRequests[2])),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )
    }

    func test_pull_request_with_integration_label_and_conflicts() {

        let target = MergeServiceFixture.defaultTarget.with(mergeState: .dirty)

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
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: [target.reference]),
                    MergeService.State.stub(status: .integrating(target)),
                    MergeService.State.stub(status: .integrationFailed(target, .conflicts)),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )
    }

    func test_pull_request_with_integration_label_and_behind_target_branch() {
        perform(
            stubs: [
                .getPullRequests { [MergeServiceFixture.defaultTarget.reference] },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .clean) },
                .getCommitStatus { _ in CommitState.stub(states: [.success]) },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in

                scheduler.advance()

                service.eventsObserver.send(value: .pullRequest(
                    .init(action: .synchronize, pullRequestMetadata: MergeServiceFixture.defaultTarget.with(mergeState: .blocked)))
                )

                scheduler.advance()

                service.sendStatusEvent(state: .success)

                scheduler.advance(by: .seconds(60))
            },
            assert: {
                expect($0) == [
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: [MergeServiceFixture.defaultTarget.reference]),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget)),
                    MergeService.State.stub(status: .runningStatusChecks(MergeServiceFixture.defaultTarget.with(mergeState: .blocked))),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget.with(mergeState: .clean))),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )
    }

    func test_pull_request_blocked_with_successful_status() {
        perform(
            stubs: [
                .getPullRequests { [MergeServiceFixture.defaultTarget.reference] },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .blocked) },
                .postComment { _, _ in },
                .getCommitStatus { _ in CommitState.stub(states: [.success]) },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .clean) },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in
                scheduler.advance()

                service.sendStatusEvent(state: .success)

                scheduler.advance()
            },
            assert: {
                expect($0) == [
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: [MergeServiceFixture.defaultTarget.reference]),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget.with(mergeState: .blocked))),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget.with(mergeState: .clean))),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )
    }

    func test_resuming_after_labelling_a_pull_request() {

        let target = PullRequestMetadata.stub(number: 1, headRef: MergeServiceFixture.defaultBranch, labels: [], mergeState: .clean)
        let targetLabeled = target.with(labels: [LabelFixture.integrationLabel])

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
                service.eventsObserver.send(value: .pullRequest(
                    .init(action: .labeled, pullRequestMetadata: targetLabeled))
                )
                scheduler.advance()
            },
            assert: {
                expect($0) == [
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .idle),
                    MergeService.State.stub(status: .ready, pullRequests: [targetLabeled.reference]),
                    MergeService.State.stub(status: .integrating(targetLabeled)),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
        }
        )
    }

    func test_adding_a_new_pull_request_while_running_an_integrating() {

        let first = MergeServiceFixture.defaultTarget.with(mergeState: .behind)
        let second = PullRequestMetadata.stub(number: 2, labels: [LabelFixture.integrationLabel], mergeState: .clean)

        perform(
            stubs: [
                .getPullRequests { [first.reference] },
                .getPullRequest { _ in first },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success },
                .postComment { message, pullRequest in
                    expect(message) == "Your pull request was accepted and it's currently `#1` in the queue, hold tight ⏳"
                    expect(pullRequest.number) == 2
                },
                .getPullRequest { _ in first.with(mergeState: .clean) },
                .getCommitStatus { _ in CommitState.stub(states: [.success]) },
                .mergePullRequest { _ in },
                .deleteBranch { _ in },
                .getPullRequest { _ in second },
                .mergePullRequest { _ in },
                .deleteBranch { _ in },
            ],
            when: { service, scheduler in

                scheduler.advance()

                service.eventsObserver.send(value: .pullRequest(
                    .init(action: .synchronize, pullRequestMetadata: first.with(mergeState: .blocked)))
                )

                scheduler.advance()

                service.eventsObserver.send(value: .pullRequest(
                    .init(action: .labeled, pullRequestMetadata: second))
                )

                scheduler.advance()

                service.sendStatusEvent(state: .success)

                scheduler.advance(by: .seconds(60))
            },
            assert: {
                expect($0) == [
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: [first.reference]),
                    MergeService.State.stub(status: .integrating(first)),
                    MergeService.State.stub(status: .runningStatusChecks(first.with(mergeState: .blocked))),
                    MergeService.State.stub(status: .runningStatusChecks(first.with(mergeState: .blocked)), pullRequests: [second.reference]),
                    MergeService.State.stub(status: .integrating(first.with(mergeState: .clean)), pullRequests: [second.reference]),
                    MergeService.State.stub(status: .ready, pullRequests: [second.reference]),
                    MergeService.State.stub(status: .integrating(second)),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )
    }

    func test_closing_pull_request_during_integration() {
        perform(
            stubs: [
                .getPullRequests { [MergeServiceFixture.defaultTarget.reference] },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success }
            ],
            when: { service, scheduler in
                scheduler.advance()

                service.eventsObserver.send(value: .pullRequest(
                    .init(action: .synchronize, pullRequestMetadata: MergeServiceFixture.defaultTarget.with(mergeState: .blocked)))
                )

                scheduler.advance()

                service.eventsObserver.send(value: .pullRequest(
                    .init(action: .closed, pullRequestMetadata: MergeServiceFixture.defaultTarget))
                )

                scheduler.advance()
            },
            assert: {
                expect($0) == [
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: [MergeServiceFixture.defaultTarget.reference]),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget)),
                    MergeService.State.stub(status: .runningStatusChecks(MergeServiceFixture.defaultTarget.with(mergeState: .blocked))),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )
    }

    func test_removing_the_integration_label_during_integration() {
        perform(
            stubs: [
                .getPullRequests { [MergeServiceFixture.defaultTarget.reference] },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success }
            ],
            when: { service, scheduler in
                scheduler.advance()

                service.eventsObserver.send(value: .pullRequest(
                    .init(action: .synchronize, pullRequestMetadata: MergeServiceFixture.defaultTarget.with(mergeState: .blocked)))
                )

                scheduler.advance()

                service.eventsObserver.send(value:
                    .pullRequest(.init(action: .unlabeled, pullRequestMetadata: MergeServiceFixture.defaultTarget.with(labels: [])))
                )

                scheduler.advance()
            },
            assert: {
                expect($0) == [
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: [MergeServiceFixture.defaultTarget.reference]),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget)),
                    MergeService.State.stub(status: .runningStatusChecks(MergeServiceFixture.defaultTarget.with(mergeState: .blocked))),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )
    }

    func test_pull_request_with_status_checks_failing() {
        perform(
            stubs: [
                .getPullRequests { [MergeServiceFixture.defaultTarget.reference] },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .blocked) },
                .getCommitStatus { _ in CommitState.stub(states: [.failure]) },
                .getRequiredStatusChecks { _ in RequiredStatusChecks.stub(indices: [0]) },
                .postComment { _, _ in },
                .removeLabel { _, _ in }
            ],
            when: { service, scheduler in
                scheduler.advance()

                service.eventsObserver.send(value: .pullRequest(
                    .init(action: .synchronize, pullRequestMetadata: MergeServiceFixture.defaultTarget.with(mergeState: .blocked)))
                )

                scheduler.advance()

                service.sendStatusEvent(state: .failure)

                scheduler.advance(by: .seconds(60))
            },
            assert: {
                expect($0) == [
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: [MergeServiceFixture.defaultTarget.reference]),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget)),
                    MergeService.State.stub(status: .runningStatusChecks(MergeServiceFixture.defaultTarget.with(mergeState: .blocked))),
                    MergeService.State.stub(status: .integrationFailed(MergeServiceFixture.defaultTarget.with(mergeState: .blocked), .checksFailing)),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )
    }

    func test_pull_request_with_multiple_status_checks() {
        let requiredStatusChecks = RequiredStatusChecks.stub(indices: [0,1,2,3,4])

        perform(
            stubs: [
                .getPullRequests { [MergeServiceFixture.defaultTarget.reference] },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .blocked) },
                .getCommitStatus { _ in CommitState.stub(states: [.pending]) },
                .getRequiredStatusChecks{ _ in requiredStatusChecks },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .blocked) },
                .getCommitStatus { _ in CommitState.stub(states: [.pending]) },
                .getRequiredStatusChecks{ _ in requiredStatusChecks },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .clean) },
                .getCommitStatus { _ in CommitState.stub(states: [.success]) },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in
                scheduler.advance()

                service.eventsObserver.send(value: .pullRequest(
                    .init(action: .synchronize, pullRequestMetadata: MergeServiceFixture.defaultTarget.with(mergeState: .blocked)))
                )

                scheduler.advance()

                for _ in 1...3 {
                    service.sendStatusEvent(state: .success)
                    scheduler.advance(by: .seconds(60))
                }
            },
            assert: {
                expect($0) == [
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: [MergeServiceFixture.defaultTarget.reference]),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget)),
                    MergeService.State.stub(status: .runningStatusChecks(MergeServiceFixture.defaultTarget.with(mergeState: .blocked))),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget.with(mergeState: .clean))),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )
    }

    func test_pull_request_with_non_required_failed_status_checks_requiresAllStatusChecks_off() {
        let requiredStatusChecks = RequiredStatusChecks.stub(indices: [0,1,3])

        perform(
            requiresAllStatusChecks: false,
            stubs: [
                .getPullRequests { [MergeServiceFixture.defaultTarget.reference] },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success },
                // 1
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .blocked) },
                .getCommitStatus { _ in CommitState.stub(states: [.pending, .pending, .pending]) },
                .getRequiredStatusChecks { _ in requiredStatusChecks },
                // 2
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .blocked) },
                .getCommitStatus { _ in CommitState.stub(states: [.success, .success, .pending, .pending, .pending]) },
                .getRequiredStatusChecks { _ in requiredStatusChecks },
                // 3
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .unstable) },
                .getCommitStatus { _ in CommitState.stub(states: [.success, .success, .pending, .success, .failure]) },
                .getRequiredStatusChecks { _ in requiredStatusChecks },
                // 4
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in
                scheduler.advance()

                service.eventsObserver.send(value: .pullRequest(
                    .init(action: .synchronize, pullRequestMetadata: MergeServiceFixture.defaultTarget.with(mergeState: .blocked)))
                )

                scheduler.advance() // 1

                scheduler.advance(by: .seconds(60)) // 2
                service.sendStatusEvent(index: 0, state: .success)
                // service.sendStatusEvent(index: 1, state: .success)
                scheduler.advance(by: .seconds(60)) // 3
                service.sendStatusEvent(index: 3, state: .success)
                scheduler.advance(by: .seconds(60)) // 4
                service.sendStatusEvent(index: 2, state: .failure)
                scheduler.advance(by: .seconds(60)) // 5
            },
            assert: {
                expect($0) == [
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: [MergeServiceFixture.defaultTarget.reference]),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget)),
                    MergeService.State.stub(status: .runningStatusChecks(MergeServiceFixture.defaultTarget.with(mergeState: .blocked))),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget.with(mergeState: .unstable))),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )
    }

    func test_pull_request_with_non_required_failed_status_checks_requiresAllStatusChecks_on() {
        perform(
            requiresAllStatusChecks: true,
            stubs: [
                .getPullRequests { [MergeServiceFixture.defaultTarget.reference] },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success },
                // 1
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .blocked) },
                .getCommitStatus { _ in CommitState.stub(states: [.pending, .pending, .pending]) },
                // 2
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .blocked) },
                .getCommitStatus { _ in CommitState.stub(states: [.success, .success, .pending, .pending, .pending]) },
                // 3
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .unstable) },
                .getCommitStatus { _ in CommitState.stub(states: [.success, .success, .pending, .success, .failure]) },
                // 4
                .postComment { _, _ in },
                .removeLabel { _, _ in }
            ],
            when: { service, scheduler in
                scheduler.advance()

                service.eventsObserver.send(value: .pullRequest(
                    .init(action: .synchronize, pullRequestMetadata: MergeServiceFixture.defaultTarget.with(mergeState: .blocked)))
                )

                scheduler.advance() // 1

                scheduler.advance(by: .seconds(60)) // 2
                service.sendStatusEvent(index: 0, state: .success)
                // service.sendStatusEvent(index: 1, state: .success)
                scheduler.advance(by: .seconds(60)) // 3
                service.sendStatusEvent(index: 3, state: .success)
                scheduler.advance(by: .seconds(60)) // 4
                service.sendStatusEvent(index: 2, state: .failure)
                scheduler.advance(by: .seconds(60)) // 5
        },
            assert: {
                expect($0) == [
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: [MergeServiceFixture.defaultTarget.reference]),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget)),
                    MergeService.State.stub(status: .runningStatusChecks(MergeServiceFixture.defaultTarget.with(mergeState: .blocked))),
                    MergeService.State.stub(status: .integrationFailed(MergeServiceFixture.defaultTarget.with(mergeState: .unstable), .checksFailing)),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
        }
        )
    }

    func test_pull_request_fails_integration_after_timeout() {

        perform(
            stubs: [
                .getPullRequests { [MergeServiceFixture.defaultTarget.reference] },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success },
                .postComment { comment, _ in
                    expect(comment) == "@John Doe unfortunately the integration failed with code: `timedOut`."
                },
                .removeLabel { _, _ in }
                ],
            when: { service, scheduler in
                scheduler.advance()

                service.eventsObserver.send(value:
                    .pullRequest(.init(action: .synchronize, pullRequestMetadata: MergeServiceFixture.defaultTarget.with(mergeState: .blocked)))
                )

                // 1.5 ensures we trigger the timeout
                scheduler.advance(by: .minutes(1.5 * MergeServiceFixture.defaultStatusChecksTimeout))
            },
            assert: {
                expect($0) == [
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: [MergeServiceFixture.defaultTarget.reference]),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget)),
                    MergeService.State.stub(status: .runningStatusChecks(MergeServiceFixture.defaultTarget.with(mergeState: .blocked))),
                    MergeService.State.stub(status: .integrationFailed(MergeServiceFixture.defaultTarget.with(mergeState: .blocked), .timedOut)),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )
    }

    func test_pull_request_with_an_initial_unknown_state_with_recover() {
        perform(
            stubs: [
                .getPullRequests { [MergeServiceFixture.defaultTarget.reference] },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .unknown) },
                .postComment { _, _ in },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .unknown) },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .unknown) },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .clean) },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in
                scheduler.advance(by: .seconds(60))
            },
            assert: {
                expect($0) == [
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: [MergeServiceFixture.defaultTarget.reference]),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget.with(mergeState: .unknown))),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget.with(mergeState: .clean))),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )
    }

    func test_pull_request_with_an_initial_unknown_state_without_recover() {
        perform(
            stubs: [
                .getPullRequests { [MergeServiceFixture.defaultTarget.reference] },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .unknown) },
                .postComment { _, _ in },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .unknown) },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .unknown) },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .unknown) },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .unknown) },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget.with(mergeState: .unknown) },
                .postComment { _, _ in },
                .removeLabel { _, _ in }
            ],
            when: { service, scheduler in
                scheduler.advance(by: .seconds(5 * 30))
            },
            assert: {
                expect($0) == [
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: [MergeServiceFixture.defaultTarget.reference]),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget.with(mergeState: .unknown))),
                    MergeService.State.stub(status: .integrationFailed(MergeServiceFixture.defaultTarget.with(mergeState: .unknown), .unknown)),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )
    }

    func test_excluding_pull_request_in_the_queue() {

        let first = MergeServiceFixture.defaultTarget.with(mergeState: .behind)
        let second = PullRequestMetadata.stub(number: 2, labels: [LabelFixture.integrationLabel], mergeState: .clean)

        perform(
            stubs: [
                .getPullRequests { [first, second].map { $0.reference} },
                .getPullRequest { _ in first },
                .postComment { _, _ in },
                .postComment { _, _ in },
                .mergeIntoBranch { _, _ in .success },
                .getPullRequest { _ in first.with(mergeState: .clean) },
                .getCommitStatus { _ in CommitState.stub(states: [.success]) },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in

                scheduler.advance()

                service.eventsObserver.send(value:
                    .pullRequest(.init(action: .synchronize, pullRequestMetadata: first.with(mergeState: .blocked)))
                )

                scheduler.advance()

                service.eventsObserver.send(value:
                    .pullRequest(.init(action: .unlabeled, pullRequestMetadata: second.with(labels: [])))
                )

                scheduler.advance()

                service.sendStatusEvent(state: .failure)

                scheduler.advance(by: .seconds(60))
            },
            assert: {
                expect($0) == [
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: [first, second].map { $0.reference}),
                    MergeService.State.stub(status: .integrating(first), pullRequests: [second.reference]),
                    MergeService.State.stub(status: .runningStatusChecks(first.with(mergeState: .blocked)), pullRequests: [second.reference]),
                    MergeService.State.stub(status: .runningStatusChecks(first.with(mergeState: .blocked))),
                    MergeService.State.stub(status: .integrating(first.with(mergeState: .clean))),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )
    }

    func test_changing_pull_request_priorities() {

        let pr1 = PullRequestMetadata.stub(number: 1, labels: [LabelFixture.integrationLabel], mergeState: .clean)
        let pr2 = PullRequestMetadata.stub(number: 2, labels: [LabelFixture.integrationLabel, LabelFixture.topPriorityLabels[0]], mergeState: .behind)
        let pr3 = PullRequestMetadata.stub(number: 3, labels: [LabelFixture.integrationLabel], mergeState: .clean)
        let pr4 = PullRequestMetadata.stub(number: 4, labels: [LabelFixture.integrationLabel], mergeState: .clean)
        let allPRs: [PullRequestMetadata] = [pr1, pr2, pr3, pr4]

        func fetchMergeDelete(expectedPRNumber: UInt) -> [MockGitHubAPI.Stubs] {
            return [
                .getPullRequest { (num: UInt) -> PullRequestMetadata in
                    expect(num) == expectedPRNumber
                    return allPRs.first { $0.reference.number == num }!
                },
                .mergePullRequest { pr in expect(pr.number) == expectedPRNumber },
                .deleteBranch { _ in }
            ]
        }
        func expectComment(for expectedPRNumber: Int) -> (String, PullRequest) -> Void {
            return { (_: String, pr: PullRequest) -> Void in
                expect(pr.number) == UInt(expectedPRNumber)
            }
        }

        perform(
            stubs: [
                .getPullRequests { Array(allPRs).map { $0.reference} },
                // advance() #1
                .getPullRequest { (num: UInt) -> PullRequestMetadata in
                    expect(num) == 2
                    return allPRs.first { $0.reference.number == num }!
                },
                .postComment(expectComment(for: 2)),
                .postComment(expectComment(for: 1)),
                .postComment(expectComment(for: 3)),
                .postComment(expectComment(for: 4)),
                .mergeIntoBranch { _, _ in .success },
                // advance() #2
                .postComment(expectComment(for: 3)), // new comment after reprio
                // advance() #3
                // advance() #4
                .getPullRequest { (num: UInt) -> PullRequestMetadata in
                    expect(num) == 2
                    return pr2.with(mergeState: .clean)
                },
                .getCommitStatus { _ in CommitState.stub(states: [.success]) },
                .mergePullRequest { (pr: PullRequest) -> Void in expect(pr.number) == 2 },
                .deleteBranch { _ in },
            ]
            + fetchMergeDelete(expectedPRNumber: 3)
            + fetchMergeDelete(expectedPRNumber: 1)
            + fetchMergeDelete(expectedPRNumber: 4)
            ,
            when: { service, scheduler in

                scheduler.advance() // #1

                service.eventsObserver.send(value:
                    .pullRequest(.init(action: .labeled, pullRequestMetadata: pr3.with(
                        labels: [LabelFixture.integrationLabel, LabelFixture.topPriorityLabels[1]]
                    )))
                )

                scheduler.advance() // #2

                service.eventsObserver.send(value:
                    .pullRequest(.init(action: .synchronize, pullRequestMetadata: pr2.with(mergeState: .blocked)))
                )

                scheduler.advance() // #3

                service.sendStatusEvent(state: .success, branches: [.init(name: pr2.reference.source.ref)])

                scheduler.advance(by: .seconds(60)) // #4
        },
            assert: {
                let pr3_tp = pr3.with(labels: [LabelFixture.integrationLabel, LabelFixture.topPriorityLabels[1]])
                expect($0) == [
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: [pr2, pr1, pr3, pr4].map{$0.reference}),
                    MergeService.State.stub(status: .integrating(pr2), pullRequests: [pr1, pr3, pr4].map{$0.reference}),
                    MergeService.State.stub(status: .integrating(pr2), pullRequests: [pr3_tp, pr1, pr4].map{$0.reference}),
                    MergeService.State.stub(status: .runningStatusChecks(pr2.with(mergeState: .blocked)), pullRequests: [pr3_tp, pr1, pr4].map{$0.reference}),
                    MergeService.State.stub(status: .integrating(pr2.with(mergeState: .clean)), pullRequests: [pr3_tp, pr1, pr4].map{$0.reference}),
                    MergeService.State.stub(status: .ready, pullRequests: [pr3_tp, pr1, pr4].map{$0.reference}),
                    MergeService.State.stub(status: .integrating(pr3), pullRequests: [pr1, pr4].map{$0.reference}),
                    MergeService.State.stub(status: .ready, pullRequests: [pr1, pr4].map{$0.reference}),
                    MergeService.State.stub(status: .integrating(pr1), pullRequests: [pr4].map{$0.reference}),
                    MergeService.State.stub(status: .ready, pullRequests: [pr4].map{$0.reference}),
                    MergeService.State.stub(status: .integrating(pr4)),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
        }
        )
    }



    func test_pull_requests_receive_feedback_when_accepted() {

        let pullRequests = [144, 233, 377]
            .map {
                PullRequestMetadata.stub(number: $0, labels: [LabelFixture.integrationLabel])
                    .with(mergeState: .clean)
        }

        perform(
            stubs: [
                .getPullRequests { pullRequests.map { $0.reference } },
                .getPullRequest { _ in pullRequests[0] },
                .postComment { message, pullRequest in
                    expect(message) == "Your pull request was accepted and is going to be handled right away 🏎"
                    expect(pullRequest.number) == 144
                },
                .postComment { message, pullRequest in
                    expect(message) == "Your pull request was accepted and it's currently `#2` in the queue, hold tight ⏳"
                    expect(pullRequest.number) == 233
                },
                .postComment { message, pullRequest in
                    expect(message) == "Your pull request was accepted and it's currently `#3` in the queue, hold tight ⏳"
                    expect(pullRequest.number) == 377
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
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: pullRequests.map { $0.reference }),
                    MergeService.State.stub(status: .integrating(pullRequests[0]), pullRequests: pullRequests.map { $0.reference }.suffix(2).asArray),
                    MergeService.State.stub(status: .ready, pullRequests: pullRequests.map { $0.reference }.suffix(2).asArray),
                    MergeService.State.stub(status: .integrating(pullRequests[1]), pullRequests: pullRequests.map { $0.reference }.suffix(1).asArray),
                    MergeService.State.stub(status: .ready, pullRequests: pullRequests.map { $0.reference }.suffix(1).asArray),
                    MergeService.State.stub(status: .integrating(pullRequests[2])),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )
    }

    func test_pull_request_does_not_fail_prematurely_if_checks_complete_before_adding_the_following_checks() {

        var expectedPullRequest = MergeServiceFixture.defaultTarget.with(mergeState: .blocked)
        var expectedCommitStatus = CommitState.stub(states: [.success])
        let expectedRequiredStatusChecks = RequiredStatusChecks.stub(indices: [0])

        perform(
            stubs: [
                .getPullRequests { [MergeServiceFixture.defaultTarget.reference] },
                .getPullRequest { _ in MergeServiceFixture.defaultTarget },
                .postComment { _, _  in },
                .mergeIntoBranch { _, _ in .success },
                .getPullRequest { _ in expectedPullRequest },
                .getCommitStatus { _ in expectedCommitStatus },
                .getRequiredStatusChecks { _ in expectedRequiredStatusChecks },
                .getPullRequest { _ in expectedPullRequest },
                .getCommitStatus { _ in expectedCommitStatus },
                .mergePullRequest { _ in },
                .deleteBranch { _ in }
            ],
            when: { service, scheduler in
                scheduler.advance()

                service.eventsObserver.send(value: .pullRequest(
                    .init(action: .synchronize, pullRequestMetadata: MergeServiceFixture.defaultTarget.with(mergeState: .blocked)))
                )

                scheduler.advance()

                service.sendStatusEvent(state: .success)

                scheduler.advance(by: .seconds(30))

                // Simulate a new check being added

                expectedCommitStatus = CommitState.stub(states: [.pending, .success])

                scheduler.advance(by: .seconds(30))

                // Simulate all checks being successful

                service.sendStatusEvent(state: .success)

                expectedPullRequest = MergeServiceFixture.defaultTarget.with(mergeState: .clean)
                expectedCommitStatus = CommitState.stub(states: [.success, .success])

                scheduler.advance(by: .seconds(60))
            },
            assert: {
                expect($0) == [
                    MergeService.State.stub(status: .starting),
                    MergeService.State.stub(status: .ready, pullRequests: [MergeServiceFixture.defaultTarget.reference]),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget)),
                    MergeService.State.stub(status: .runningStatusChecks(MergeServiceFixture.defaultTarget.with(mergeState: .blocked))),
                    MergeService.State.stub(status: .integrating(MergeServiceFixture.defaultTarget.with(mergeState: .clean))),
                    MergeService.State.stub(status: .ready),
                    MergeService.State.stub(status: .idle)
                ]
            }
        )
    }

    // TODO: [CNSMR-2525] Add test for failure cases

    // MARK: - Helpers

    struct MockGitHubEventsService: GitHubEventsServiceProtocol {
        let eventsObserver: Signal<Event, NoError>.Observer
        let events: Signal<Event, NoError>

        init() {
            (events, eventsObserver) = Signal.pipe()
        }

        func sendStatusEvent(
            index: Int = 0,
            state: StatusEvent.State,
            branches: [StatusEvent.Branch] = [.init(name: MergeServiceFixture.defaultBranch)]
        ) {
            eventsObserver.send(value: .status(
                StatusEvent(
                    sha: "abcdef",
                    context: CommitState.stubContextName(index),
                    description: "N/A",
                    state: state,
                    branches: branches
                )
            ))
        }
    }

    private func perform(
        requiresAllStatusChecks: Bool = false,
        stubs: [MockGitHubAPI.Stubs],
        when: (MockGitHubEventsService, TestScheduler) -> Void,
        assert: ([MergeService.State]) -> Void
    ) {

        let scheduler = TestScheduler()
        let gitHubAPI = MockGitHubAPI(stubs: stubs)
        let gitHubEvents = MockGitHubEventsService()

        var states: [MergeService.State] = []

        _ = DispatchService(
            integrationLabel: LabelFixture.integrationLabel,
            topPriorityLabels: LabelFixture.topPriorityLabels,
            requiresAllStatusChecks: requiresAllStatusChecks,
            statusChecksTimeout: MergeServiceFixture.defaultStatusChecksTimeout,
            logger: MockLogger(),
            gitHubAPI: gitHubAPI,
            gitHubEvents: gitHubEvents,
            scheduler: scheduler,
            onNewMergeService: { service in
                service.state.producer.observe(on: scheduler).startWithValues { states.append($0) }
            }
        )

        when(gitHubEvents, scheduler)
        assert(states)

        expect(gitHubAPI.assert()) == true
    }
}
