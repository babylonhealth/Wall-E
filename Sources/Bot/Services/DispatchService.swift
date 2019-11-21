import Foundation
import Result
import ReactiveSwift
import ReactiveFeedback

public final class DispatchService {
    private let integrationLabel: PullRequest.Label
    private let topPriorityLabels: [PullRequest.Label]
    private let requiresAllStatusChecks: Bool
    private let statusChecksTimeout: TimeInterval

    private let logger: LoggerProtocol
    private let gitHubAPI: GitHubAPIProtocol
    private let scheduler: DateScheduler

    private var mergeServices: [String: MergeService]

//    public let healthcheck: Healthcheck // TODO: IOSP-164: Decomment when ready to tweak

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

        self.mergeServices = [:]

        // TODO: IOSP-164: Don't forget to handle the boot sequence (fetching current list of PRs and dispatching them)

        // TODO: IOSP-164: Decomment once healthcheck is ready again
//        healthcheck = Healthcheck(state: state.signal, statusChecksTimeout: statusChecksTimeout, scheduler: scheduler)

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

    private func pullRequestDidChange(event: PullRequestEvent) {
        logger.log("📣 Pull Request did change \(event.pullRequestMetadata) with action `\(event.action)`")
        let prTargetBranch = event.pullRequestMetadata.reference.target.ref

        let mergeService: MergeService
        if let service = mergeServices[prTargetBranch] {
            mergeService = service
        } else {
            mergeService = makeMergeService(targetBranch: prTargetBranch)
            mergeServices[prTargetBranch] = mergeService
            // TODO: IOSP-164: Hook to mergeService.state.status so that when it's back in `.idle` then we can consider cleaning it up from the dict
        }

        mergeService.pullRequestChangesObserver.send(value: (event.pullRequestMetadata, event.action))
    }

    private func statusChecksDidChange(event: StatusEvent) {
        let prTargetBranch = ""
        guard let mergeService = mergeServices[prTargetBranch] else {
            logger.log("🚨 Received status check change for \(event) but no MergeService responsible for branch \(prTargetBranch) were running")
            return
        }
        mergeService.statusChecksCompletionObserver.send(value: event)
    }

    private func makeMergeService(targetBranch: String) -> MergeService {
        return MergeService(
            targetBranch: targetBranch,
            integrationLabel: integrationLabel,
            topPriorityLabels: topPriorityLabels,
            requiresAllStatusChecks: requiresAllStatusChecks,
            statusChecksTimeout: statusChecksTimeout,
            logger: logger,
            gitHubAPI: gitHubAPI
        )
    }
}

extension DispatchService {
    public var queuesDescription: String {
        mergeServices.map { (entry: (key: String, value: MergeService)) -> String in
            """
            ## Merge Queue for target branch: \(entry.key) ##

            \(entry.value.state.value)
            """
        }.joined(separator: "\n\n")
    }
}

// MARK: - System types

/* // TODO: IOSP-164: Decomment when ready to tweak
extension DispatchService {
    public final class Healthcheck {

        public enum Reason: Error, Equatable {
            case potentialDeadlock
        }

        public enum Status: Equatable {
            case ok
            case unhealthy(Reason)
        }

        public let status: Property<Status>

        internal init(
            state: Signal<State, NoError>,
            statusChecksTimeout: TimeInterval,
            scheduler: DateScheduler
        ) {
            status = Property(
                initial: .ok,
                then: state.combinePrevious()
                    .skipRepeats { lhs, rhs in
                        return lhs == rhs
                    }
                    .flatMap(.latest) { _, current -> SignalProducer<Status, NoError> in
                        switch current.status {
                        case .starting, .idle:
                            return SignalProducer(value: .ok)
                        default:
                            return SignalProducer(value: .unhealthy(.potentialDeadlock))
                                // Status checks have a configurable timeout that is used to prevent blocking the queue
                                // if for some reason there's an issue with them, we are following a strategy where we
                                // plan the potential failure and delay it for the expected amount of time that they
                                // should have take at most (timeout) plus a sensible leeway. Due how `flatMap(.latest)`
                                // works, any new `state` triggered before this delay will interrupt this signal and
                                // prevent the false failure otherwise there's something blocking the queue longer than
                                // we antecipated and we should flag the failure.
                                .delay(1.5 * statusChecksTimeout, on: scheduler)
                        }
                }
            )
        }
    }
}
*/
