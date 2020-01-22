import ReactiveSwift
@testable import Bot

struct MockGitHubEventsService: GitHubEventsServiceProtocol {
    let eventsObserver: Signal<Event, Never>.Observer
    let events: Signal<Event, Never>

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

    func sendPullRequestEvent(action: PullRequest.Action, pullRequestMetadata: PullRequestMetadata) {
        eventsObserver.send(value: .pullRequest(
            .init(action: action, pullRequestMetadata: pullRequestMetadata))
        )
    }
}
