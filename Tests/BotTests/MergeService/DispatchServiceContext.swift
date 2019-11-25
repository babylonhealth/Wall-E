import ReactiveSwift
import Result
@testable import Bot

enum DispatchServiceEvent: Equatable {
    case created(branch: String)
    case state(branch: String, MergeService.State)
    case destroyed(branch: String)

    static func state(_ state: MergeService.State) -> DispatchServiceEvent {
        // IOSP-169: Once we migrate to Swift 5 we can change that to being a default value for enum associated value
        return .state(branch: MergeServiceFixture.defaultTargetBranch, state)
    }

    init(from lifecycleEvent: DispatchService.MergeServiceLifecycleEvent) {
        switch lifecycleEvent {
        case .created(let service):
            self = .created(branch: service.targetBranch)
        case .stateChanged(let service):
            self = .state(branch: service.targetBranch, service.state.value)
        case .destroyed(let service):
            self = .destroyed(branch: service.targetBranch)
        }
    }

    var branch: String {
        switch self {
        case .created(let branch), .state(let branch, _), .destroyed(let branch):
            return branch
        }

    }
}

class DispatchServiceContext {
    let dispatchService: DispatchService
    var events: [DispatchServiceEvent] = []

    init(requiresAllStatusChecks: Bool, gitHubAPI: GitHubAPIProtocol, gitHubEvents: GitHubEventsServiceProtocol, scheduler: DateScheduler) {
        let (lifecycleSignal, lifecycleObserver) = Signal<DispatchService.MergeServiceLifecycleEvent, NoError>.pipe()

        self.dispatchService = DispatchService(
            integrationLabel: LabelFixture.integrationLabel,
            topPriorityLabels: LabelFixture.topPriorityLabels,
            requiresAllStatusChecks: requiresAllStatusChecks,
            statusChecksTimeout: MergeServiceFixture.defaultStatusChecksTimeout,
            logger: MockLogger(),
            gitHubAPI: gitHubAPI,
            gitHubEvents: gitHubEvents,
            scheduler: scheduler,
            mergeServiceLifecycleObserver: lifecycleObserver
        )

        lifecycleSignal
            .map(DispatchServiceEvent.init)
            .observe(on: scheduler)
            .observeValues { [weak self] event in
                self?.events.append(event)
            }
    }
}
