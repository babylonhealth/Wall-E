import ReactiveSwift
import Result
import Dispatch
@testable import Bot

enum DispatchServiceEvent: Equatable {
    case created(branch: String)
    case state(MergeService.State)
    case destroyed(branch: String)

    init(from lifecycleEvent: DispatchService.MergeServiceLifecycleEvent) {
        switch lifecycleEvent {
        case .created(let service):
            self = .created(branch: service.state.value.targetBranch)
        case .stateChanged(let service):
            self = .state(service.state.value)
        case .destroyed(let service):
            self = .destroyed(branch: service.state.value.targetBranch)
        }
    }

    var branch: String {
        switch self {
        case .created(let branch), .destroyed(let branch):
            return branch
        case .state(let state):
            return state.targetBranch
        }
    }
}

class DispatchServiceContext {
    let dispatchService: DispatchService
    var events: [DispatchServiceEvent] = []

    init(requiresAllStatusChecks: Bool, gitHubAPI: GitHubAPIProtocol, gitHubEvents: GitHubEventsServiceProtocol, scheduler: DateScheduler) {
        self.dispatchService = DispatchService(
            integrationLabel: LabelFixture.integrationLabel,
            topPriorityLabels: LabelFixture.topPriorityLabels,
            requiresAllStatusChecks: requiresAllStatusChecks,
            statusChecksTimeout: MergeServiceFixture.defaultStatusChecksTimeout,
            idleMergeServiceCleanupDelay: MergeServiceFixture.defaultIdleCleanupDelay,
            logger: MockLogger(),
            gitHubAPI: gitHubAPI,
            gitHubEvents: gitHubEvents,
            scheduler: scheduler
        )

        self.dispatchService.mergeServiceLifecycle
            .on(event: { (event: Signal<DispatchService.MergeServiceLifecycleEvent, NoError>.Event) in
                print("Lifecycle Event: \(event)")
                if case .value(.stateChanged(let ms)) = event {
                    print("Lifecycle Event: New state is \(ms.state.value)")
                }
            }, completed: {
                print("Lifecycle .completed")
            }, interrupted: {
                print("Lifecycle .interupted")
            }, terminated: {
                print("Lifecycle .terminated")
            }, disposed: {
                print("Lifecycle .disposed")
            })
            .map(DispatchServiceEvent.init)
            .observe(on: scheduler)
            .observeValues { [weak self] event in
                self?.events.append(event)
            }
    }

    deinit {
        print("DispatchServiceContext deinit")
    }
    static let idleCleanupDelay: DispatchTimeInterval = .seconds(Int(MergeServiceFixture.defaultIdleCleanupDelay))
}
