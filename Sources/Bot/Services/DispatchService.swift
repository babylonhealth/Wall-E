import Foundation
import Result
import ReactiveSwift
import ReactiveFeedback

/// Orchestrates multiple merge services, one per each target branch of PRs enqueued for integration
public final class DispatchService {
    private let integrationLabel: PullRequest.Label
    private let topPriorityLabels: [PullRequest.Label]
    private let requiresAllStatusChecks: Bool
    private let statusChecksTimeout: TimeInterval

    private let logger: LoggerProtocol
    private let gitHubAPI: GitHubAPIProtocol
    private let scheduler: DateScheduler

    /// Merge services per target branch
    private var mergeServices: [String: MergeService]
    private let mergeServiceLifecycleObserver: Signal<MergeServiceLifecycleEvent, NoError>.Observer?

    public let healthcheck: Healthcheck

    public init(
        integrationLabel: PullRequest.Label,
        topPriorityLabels: [PullRequest.Label],
        requiresAllStatusChecks: Bool,
        statusChecksTimeout: TimeInterval,
        logger: LoggerProtocol,
        gitHubAPI: GitHubAPIProtocol,
        gitHubEvents: GitHubEventsServiceProtocol,
        scheduler: DateScheduler = QueueScheduler(),
        mergeServiceLifecycleObserver: Signal<MergeServiceLifecycleEvent, NoError>.Observer? = nil
    ) {
        self.integrationLabel = integrationLabel
        self.topPriorityLabels = topPriorityLabels
        self.requiresAllStatusChecks = requiresAllStatusChecks
        self.statusChecksTimeout = statusChecksTimeout

        self.logger = logger
        self.gitHubAPI = gitHubAPI
        self.scheduler = scheduler

        self.mergeServices = [:]
        self.mergeServiceLifecycleObserver = mergeServiceLifecycleObserver

        healthcheck = Healthcheck(scheduler: scheduler)

        gitHubAPI.fetchPullRequests()
            .flatMapError { _ in .value([]) }
            .map { pullRequests in
                pullRequests.filter { $0.isLabelled(with: self.integrationLabel) }
            }
            .observe(on: scheduler)
            .startWithValues { pullRequests in
                self.dispatchInitial(pullRequests: pullRequests)
            }

        gitHubEvents.events
            .observe(on: scheduler)
            .observeValues { [weak self] gitHubEvent in
                switch gitHubEvent {
                case let .pullRequest(event):
                    self?.pullRequestDidChange(event: event)
                case let .status(event):
                    self?.statusChecksDidChange(event: event)
                case .ping:
                    break
                }
            }
    }

    private func dispatchInitial(pullRequests: [PullRequest]) {
        let dispatchTable = Dictionary(grouping: pullRequests) { $0.target.ref }
        for (branch, pullRequestsForBranch) in dispatchTable {
            makeMergeService(
                targetBranch: branch,
                scheduler: self.scheduler,
                initialPullRequests: pullRequestsForBranch
            )
        }
    }

    private func pullRequestDidChange(event: PullRequestEvent) {
        logger.log("📣 Pull Request did change \(event.pullRequestMetadata) with action `\(event.action)`")
        let targetBranch = event.pullRequestMetadata.reference.target.ref
        if let service = mergeServices[targetBranch] {
            service.pullRequestChangesObserver.send(value: (event.pullRequestMetadata, event.action))
        } else {
            makeMergeService(targetBranch: targetBranch, scheduler: self.scheduler, initialPullRequests: [event.pullRequestMetadata.reference])
        }
    }

    private func statusChecksDidChange(event: StatusEvent) {
        // No way to know which MergeService this event is supposed to be for – isRelative(toBranch:) only checks for head branch not target so not useful here
        // So we're sending it to all MergeServices, and they'll filter them themselves based on their own queues
        for mergeServiceForBranch in mergeServices.values {
            mergeServiceForBranch.statusChecksCompletionObserver.send(value: event)
        }
    }

    @discardableResult
    private func makeMergeService(targetBranch: String, scheduler: DateScheduler, initialPullRequests: [PullRequest] = []) -> MergeService {
        let mergeService = MergeService(
            targetBranch: targetBranch,
            integrationLabel: integrationLabel,
            topPriorityLabels: topPriorityLabels,
            requiresAllStatusChecks: requiresAllStatusChecks,
            statusChecksTimeout: statusChecksTimeout,
            initialPullRequests: initialPullRequests,
            logger: logger,
            gitHubAPI: gitHubAPI,
            scheduler: scheduler
        )
        self.mergeServices[targetBranch] = mergeService
        self.healthcheck.startMonitoring(mergeServiceHealthcheck: mergeService.healthcheck)
        mergeServiceLifecycleObserver?.send(value: .created(mergeService))
        mergeService.state.producer
            .observe(on: scheduler)
            .startWithValues { [weak self, service = mergeService] state in
                self?.mergeServiceLifecycleObserver?.send(value: .stateChanged(service))
                if state.status == .idle {
                    self?.mergeServices[targetBranch] = nil
                    self?.mergeServiceLifecycleObserver?.send(value: .destroyed(service))
                }
            }

        return mergeService
    }
}

extension DispatchService {
    public enum MergeServiceLifecycleEvent {
        case created(MergeService)
        case destroyed(MergeService)
        case stateChanged(MergeService)
    }
}

extension DispatchService {
    public var queuesDescription: String {
        guard !mergeServices.isEmpty else {
            return "No PR pending, all queues empty."
        }
        return mergeServices.map { (entry: (key: String, value: MergeService)) -> String in
            """
            ## Merge Queue for target branch: \(entry.key) ##

            \(entry.value.state.value)
            """
        }.joined(separator: "\n\n")
    }

    public var queueStates: [MergeService.State] {
        return self.mergeServices.values.map { $0.state.value }
    }
}

// MARK: - Healthcheck

extension DispatchService {
    public final class Healthcheck {

        public enum Reason: Error, Equatable {
            case potentialDeadlock
        }

        public enum Status: Equatable {
            case ok
            case unhealthy(Reason)
        }

        public var status: Property<Status> { return Property(_status) }

        private let scheduler: DateScheduler
        private var producers: [String: SignalProducer<MergeService.Healthcheck.Status, NoError>] = [:]
        private var statusProducerDisposable: Disposable?
        private var _status: MutableProperty<Status> = MutableProperty(.ok)

        internal init(
            scheduler: DateScheduler
        ) {
            self.scheduler = scheduler
        }

        func startMonitoring(mergeServiceHealthcheck: MergeService.Healthcheck) {
            let uuid = UUID().uuidString
            producers[uuid] = mergeServiceHealthcheck.status.producer
                .on(disposed: { [weak self] in
                    self?.producers[uuid] = nil
                })

            statusProducerDisposable?.dispose()
            statusProducerDisposable = SignalProducer
                .combineLatest(producers.values)
                .map({ (mergeServiceStatuses: [MergeService.Healthcheck.Status]) -> Healthcheck.Status in
                   mergeServiceStatuses.contains(where: { $0 != .ok }) ? .unhealthy(.potentialDeadlock) : .ok
                })
                .observe(on: scheduler)
                .startWithValues { [weak self] in
                    self?._status.value = $0
                }
        }
    }
}
