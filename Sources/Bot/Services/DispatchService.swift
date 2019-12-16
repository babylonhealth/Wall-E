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
    private let idleMergeServiceCleanupDelay: TimeInterval

    private let logger: LoggerProtocol
    private let gitHubAPI: GitHubAPIProtocol
    private let scheduler: DateScheduler

    /// Merge services per target branch
    private var mergeServices: Atomic<[String: MergeService]>
    public let mergeServiceLifecycle: Signal<DispatchService.MergeServiceLifecycleEvent, NoError>
    private let mergeServiceLifecycleObserver: Signal<DispatchService.MergeServiceLifecycleEvent, NoError>.Observer

    public init(
        integrationLabel: PullRequest.Label,
        topPriorityLabels: [PullRequest.Label],
        requiresAllStatusChecks: Bool,
        statusChecksTimeout: TimeInterval,
        idleMergeServiceCleanupDelay: TimeInterval,
        logger: LoggerProtocol,
        gitHubAPI: GitHubAPIProtocol,
        gitHubEvents: GitHubEventsServiceProtocol,
        scheduler: DateScheduler = QueueScheduler()
    ) {
        self.integrationLabel = integrationLabel
        self.topPriorityLabels = topPriorityLabels
        self.requiresAllStatusChecks = requiresAllStatusChecks
        self.statusChecksTimeout = statusChecksTimeout
        self.idleMergeServiceCleanupDelay = idleMergeServiceCleanupDelay

        self.logger = logger
        self.gitHubAPI = gitHubAPI
        self.scheduler = scheduler

        self.mergeServices = Atomic([:])
        (mergeServiceLifecycle, mergeServiceLifecycleObserver) = Signal<DispatchService.MergeServiceLifecycleEvent, NoError>.pipe()

        gitHubAPI.fetchPullRequests()
            .flatMapError { _ in .value([]) }
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
        mergeServices.modify { dict in
            for (branch, pullRequestsForBranch) in dispatchTable {
                dict[branch] = makeMergeService(
                    targetBranch: branch,
                    scheduler: self.scheduler,
                    initialPullRequests: pullRequestsForBranch
                )
            }
        }
    }

    private func pullRequestDidChange(event: PullRequestEvent) {
        logger.log("📣 Pull Request did change \(event.pullRequestMetadata) with action `\(event.action)`")

        let targetBranch = event.pullRequestMetadata.reference.target.ref
        let mergeService = mergeServices.modify { (dict: inout [String: MergeService]) -> MergeService in
            if let service = dict[targetBranch] {
                return service
            } else {
                let newService = makeMergeService(
                    targetBranch: targetBranch,
                    scheduler: self.scheduler
                )
                dict[targetBranch] = newService
                return newService
            }
        }
        mergeService.pullRequestChangesObserver.send(value: (event.pullRequestMetadata, event.action))
    }

    private func statusChecksDidChange(event: StatusEvent) {
        mergeServices.withValue { currentMergeServices in
            for mergeServiceForBranch in currentMergeServices.values {
                mergeServiceForBranch.statusChecksCompletionObserver.send(value: event)
            }
        }
    }

    private func makeMergeService(
        targetBranch: String,
        scheduler: DateScheduler,
        initialPullRequests: [PullRequest] = []
    ) -> MergeService {
        logger.log("🆕 New MergeService created for target branch `\(targetBranch)`")
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

        // Forward events about creation and subsequent state changes of the new MergeService to our lifecycleObserver
        mergeServiceLifecycleObserver.send(value: .created(mergeService))
        mergeService.state.producer
            .skipRepeats()
            .observe(on: scheduler)
            .startWithValues { [weak self, service = mergeService] state in
                self?.mergeServiceLifecycleObserver.send(value: .stateChanged(service))
            }
        // Observe idle states to clean up dormant MergeServices only after they have been idle for too long
        mergeService.state.producer
            .filter { $0.status == .idle }
            .debounce(self.idleMergeServiceCleanupDelay, on: scheduler)
            .startWithValues { [weak self, service = mergeService, logger = logger] state in
                guard let self = self else { return }

                logger.log("👋 MergeService for target branch `\(targetBranch)` has been idle for \(self.idleMergeServiceCleanupDelay)s, destroying")
                self.mergeServices.modify { dict in
                    dict[targetBranch] = nil
                }
                self.mergeServiceLifecycleObserver.send(value: .destroyed(service))
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
        let currentMergeServices = mergeServices.value
        guard !currentMergeServices.isEmpty else {
            return "No PR pending, all queues empty."
        }
        return currentMergeServices.map { (entry: (key: String, value: MergeService)) -> String in
            """
            ## Merge Queue for target branch: \(entry.key) ##

            \(entry.value.state.value)
            """
        }.joined(separator: "\n\n")
    }

    public var queueStates: [MergeService.State] {
        return self.mergeServices.value.values
            .map { $0.state.value }
            .sorted { (lhs, rhs) in
                lhs.targetBranch < rhs.targetBranch
        }
    }
}

// MARK: - Healthcheck

extension DispatchService {
    public var healthcheckStatus: MergeService.Healthcheck.Status {
        let currentStatuses = self.mergeServices.value.values.map { $0.healthcheck.status.value }
        return currentStatuses.first(where: { $0 != .ok }) ?? .ok
    }
}
