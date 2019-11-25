import ReactiveSwift
import Result
@testable import Bot

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
