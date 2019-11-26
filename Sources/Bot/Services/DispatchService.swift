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
    private var mergeServices: Atomic<[String: MergeService]>
    public let mergeServiceLifecycle: Signal<DispatchService.MergeServiceLifecycleEvent, NoError>
    private let mergeServiceLifecycleObserver: Signal<DispatchService.MergeServiceLifecycleEvent, NoError>.Observer

    public init(
        integrationLabel: PullRequest.Label,
        topPriorityLabels: [PullRequest.Label],
        requiresAllStatusChecks: Bool,
        statusChecksTimeout: TimeInterval,
        logger: LoggerProtocol,
        gitHubAPI: GitHubAPIProtocol,
        gitHubEvents: GitHubEventsServiceProtocol,
        scheduler: DateScheduler = QueueScheduler()
    ) {
        self.integrationLabel = integrationLabel
        self.topPriorityLabels = topPriorityLabels
        self.requiresAllStatusChecks = requiresAllStatusChecks
        self.statusChecksTimeout = statusChecksTimeout

        self.logger = logger
        self.gitHubAPI = gitHubAPI
        self.scheduler = scheduler

        self.mergeServices = Atomic([:])
        (mergeServiceLifecycle, mergeServiceLifecycleObserver) = Signal<DispatchService.MergeServiceLifecycleEvent, NoError>.pipe()

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
        mergeServices.modify { dict in
            if let service = dict[targetBranch] {
                service.pullRequestChangesObserver.send(value: (event.pullRequestMetadata, event.action))
            } else {
                dict[targetBranch] = makeMergeService(
                    targetBranch: targetBranch,
                    scheduler: self.scheduler,
                    initialPullRequests: [event.pullRequestMetadata.reference]
                )
            }
        }
    }

    private func statusChecksDidChange(event: StatusEvent) {
        // No way to know which MergeService this event is supposed to be for – isRelative(toBranch:) only checks for head branch not target so not useful here
        // So we're sending it to all MergeServices, and they'll filter them themselves based on their own queues
        mergeServices.withValue { currentMergeServices in
            for mergeServiceForBranch in currentMergeServices.values {
                mergeServiceForBranch.statusChecksCompletionObserver.send(value: event)
            }
        }
    }

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
        mergeServiceLifecycleObserver.send(value: .created(mergeService))
        mergeService.state.producer
            .observe(on: scheduler)
            .startWithValues { [weak self, service = mergeService] state in
                self?.mergeServiceLifecycleObserver.send(value: .stateChanged(service))
                if state.status == .idle {
                    self?.mergeServices.modify { dict in
                        dict[targetBranch] = nil
                    }
                    self?.mergeServiceLifecycleObserver.send(value: .destroyed(service))
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
