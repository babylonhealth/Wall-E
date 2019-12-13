import Foundation
import Result
import ReactiveSwift
import ReactiveFeedback

public final class MergeService {
    public let state: Property<State>
    public let healthcheck: Healthcheck

    private let logger: LoggerProtocol
    private let gitHubAPI: GitHubAPIProtocol
    private let scheduler: DateScheduler

    private let pullRequestChanges: Signal<(PullRequestMetadata, PullRequest.Action), NoError>
    internal let pullRequestChangesObserver: Signal<(PullRequestMetadata, PullRequest.Action), NoError>.Observer

    private let statusChecksCompletion: Signal<StatusEvent, NoError>
    internal let statusChecksCompletionObserver: Signal<StatusEvent, NoError>.Observer

    public init(
        targetBranch: String,
        integrationLabel: PullRequest.Label,
        topPriorityLabels: [PullRequest.Label],
        requiresAllStatusChecks: Bool,
        statusChecksTimeout: TimeInterval,
        initialTrigger: InitialTrigger,
        logger: LoggerProtocol,
        gitHubAPI: GitHubAPIProtocol,
        scheduler: DateScheduler = QueueScheduler()
    ) {
        self.logger = logger
        self.gitHubAPI = gitHubAPI
        self.scheduler = scheduler

        (statusChecksCompletion, statusChecksCompletionObserver) = Signal.pipe()

        (pullRequestChanges, pullRequestChangesObserver) = Signal.pipe()

        let initialState = State.initial(
            targetBranch: targetBranch,
            integrationLabel: integrationLabel,
            topPriorityLabels: topPriorityLabels,
            statusChecksTimeout: statusChecksTimeout
        )

        let pullRequestsReadyToInclude = initialTrigger.filteredPullRequests(integrationLabel: integrationLabel)

        state = Property<State>(
            initial: initialState,
            scheduler: scheduler,
            reduce: MergeService.reduce,
            feedbacks: [
                Feedbacks.whenStarting(initialPullRequests: pullRequestsReadyToInclude, scheduler: scheduler),
                Feedbacks.whenReady(github: self.gitHubAPI, scheduler: scheduler),
                Feedbacks.whenIntegrating(github: self.gitHubAPI, requiresAllStatusChecks: requiresAllStatusChecks, pullRequestChanges: pullRequestChanges, scheduler: scheduler),
                Feedbacks.whenRunningStatusChecks(github: self.gitHubAPI, logger: logger, requiresAllStatusChecks: requiresAllStatusChecks, statusChecksCompletion: statusChecksCompletion, scheduler: scheduler),
                Feedbacks.whenIntegrationFailed(github: self.gitHubAPI, logger: logger, scheduler: scheduler),
                Feedbacks.pullRequestChanges(pullRequestChanges: pullRequestChanges, scheduler: scheduler),
                Feedbacks.whenAddingPullRequests(github: self.gitHubAPI, scheduler: scheduler)
            ]
        )

        healthcheck = Healthcheck(state: state.signal, statusChecksTimeout: statusChecksTimeout, scheduler: scheduler)

        state.producer
            .combinePrevious()
            .startWithValues { old, new in
                logger.log("♻️ [\(new.targetBranch) queue] Did change state\n - 📜 \(old) \n - 📄 \(new)")
            }
    }

    static func reduce(state: State, event: Event) -> State {

        let reducedState: State? = {
            switch state.status {
            case .idle:
                return state.reduceIdle(with: event)
            case .starting:
                return state.reduceStarting(with: event)
            case .ready:
                return state.reduceReady(with: event)
            case let .integrating(metadata):
                return state.reduceIntegrating(with: metadata, event: event)
            case let .runningStatusChecks(metadata):
                return state.reduceRunningStatusChecks(with: metadata, event: event)
            case .integrationFailed:
                return state.reduceIntegrationFailed(with: event)
            }
        }()

        return reducedState ?? state.reduceDefault(with: event)
    }
}

// MARK: - System types

extension MergeService {

    /// Reason for which the MergeService was created: either right after initial boot of the bot or after an event routed to the service's targetBranch
    public enum InitialTrigger {
        /// The bot was just booted so we got a full list of all the open pull requests after fetching them
        case booting(openPullRequests: [PullRequest])
        /// The bot was already running and received a GitHub event which was routed to that new MergeService
        case gitHubEvent(PullRequestEvent)

        func filteredPullRequests(integrationLabel: PullRequest.Label) -> [PullRequest] {
            switch self {
            case .booting(let initialOpenPullRequests):
                return initialOpenPullRequests.filter { $0.isLabelled(with: integrationLabel) }
            case .gitHubEvent(let event):
                let outcome = eventOutcome(metadata: event.pullRequestMetadata, action: event.action, integrationLabel: integrationLabel)
                if case .include(let pullRequest) = outcome {
                    return [pullRequest]
                } else {
                    return []
                }
            }
        }
    }

    public enum FailureReason: String, Equatable, Encodable {
        case conflicts
        case mergeFailed
        case synchronizationFailed
        case checkingCommitChecksFailed
        case checksFailing
        case timedOut
        case blocked
        case unknown
    }

    public struct State: Equatable {
        public let status: Status
        public let pullRequests: [PullRequest]

        internal let targetBranch: String
        internal let integrationLabel: PullRequest.Label
        internal let topPriorityLabels: [PullRequest.Label]
        internal let statusChecksTimeout: TimeInterval

        init(
            targetBranch: String,
            integrationLabel: PullRequest.Label,
            topPriorityLabels: [PullRequest.Label],
            statusChecksTimeout: TimeInterval,
            pullRequests: [PullRequest],
            status: Status
        ) {
            self.targetBranch = targetBranch
            self.integrationLabel = integrationLabel
            self.topPriorityLabels = topPriorityLabels
            self.statusChecksTimeout = statusChecksTimeout
            self.pullRequests = pullRequests
            self.status = status
        }

        static func initial(targetBranch: String, integrationLabel: PullRequest.Label, topPriorityLabels: [PullRequest.Label], statusChecksTimeout: TimeInterval) -> State {
            return State(
                targetBranch: targetBranch,
                integrationLabel: integrationLabel,
                topPriorityLabels: topPriorityLabels,
                statusChecksTimeout: statusChecksTimeout,
                pullRequests: [],
                status: .starting
            )
        }

        var isIntegrationOngoing: Bool {
            switch status {
            case .integrating, .runningStatusChecks:
                return true
            case .starting, .idle, .ready, .integrationFailed:
                return false
            }
        }

        func with(status: Status) -> State {
            return State(
                targetBranch: targetBranch,
                integrationLabel: integrationLabel,
                topPriorityLabels: topPriorityLabels,
                statusChecksTimeout: statusChecksTimeout,
                pullRequests: pullRequests,
                status: status
            )
        }

        func include(pullRequests pullRequestsToInclude: [PullRequest]) -> State {
            let onlyNewPRs = pullRequestsToInclude.filter {
                [currentQueue = self.pullRequests] pullRequest in
                currentQueue.map({ $0.number }).contains(pullRequest.number) == false
            }
            let updatedOldPRs = pullRequests.map { (pr: PullRequest) -> PullRequest in
                pullRequestsToInclude.first { $0.number == pr.number } ?? pr
            }
            let newQueue = (updatedOldPRs + onlyNewPRs).slowStablePartition { (pullRequest: PullRequest) in
                !pullRequest.isLabelled(withOneOf: topPriorityLabels)
            }
            return State(
                targetBranch: targetBranch,
                integrationLabel: integrationLabel,
                topPriorityLabels: topPriorityLabels,
                statusChecksTimeout: statusChecksTimeout,
                pullRequests: newQueue,
                status: status
            )
        }

        func exclude(pullRequest: PullRequest) -> State {
            return State(
                targetBranch: targetBranch,
                integrationLabel: integrationLabel,
                topPriorityLabels: topPriorityLabels,
                statusChecksTimeout: statusChecksTimeout,
                pullRequests: pullRequests.filter { $0.number != pullRequest.number },
                status: status
            )
        }

        public enum Status: Equatable, Encodable {
            case starting
            case idle
            case ready
            case integrating(PullRequestMetadata)
            case runningStatusChecks(PullRequestMetadata)
            case integrationFailed(PullRequestMetadata, FailureReason)

            internal var integrationMetadata: PullRequestMetadata? {
                switch self {
                case let .integrating(metadata):
                    return metadata
                default:
                    return nil
                }
            }

            internal var statusChecksMetadata: PullRequestMetadata? {
                switch self {
                case let .runningStatusChecks(metadata):
                    return metadata
                default:
                    return nil
                }
            }

            enum CodingKeys: String, CodingKey {
                case status
                case metadata
                case error
            }

            public func encode(to encoder: Encoder) throws {
                var values = encoder.container(keyedBy: CodingKeys.self)
                switch self {
                case .starting:
                    try values.encode("starting", forKey: .status)
                case .idle:
                    try values.encode("idle", forKey: .status)
                case .ready:
                    try values.encode("ready", forKey: .status)
                case let .integrating(metadata):
                    try values.encode("integrating", forKey: .status)
                    try values.encode(metadata, forKey: .metadata)
                case let .runningStatusChecks(metadata):
                    try values.encode("runningStatusChecks", forKey: .status)
                    try values.encode(metadata, forKey: .metadata)
                case let .integrationFailed(metadata, error):
                    try values.encode("integrationFailed", forKey: .status)
                    try values.encode(metadata, forKey: .metadata)
                    try values.encode(error, forKey: .error)
                }

            }
        }
    }

    enum Event {
        case noMorePullRequests
        case pullRequestsLoaded([PullRequest])
        case pullRequestDidChange(Outcome)
        case statusChecksDidComplete(StatusChecksResult)
        case integrate(PullRequestMetadata)
        case retryIntegration(PullRequestMetadata)
        case integrationDidChangeStatus(IntegrationStatus, PullRequestMetadata)
        case integrationFailureHandled

        enum Outcome {
            case include(PullRequest)
            case exclude(PullRequest)
        }

        enum StatusChecksResult {
            case failed(PullRequestMetadata)
            case passed(PullRequestMetadata)
            case timedOut(PullRequestMetadata)
        }

        enum IntegrationStatus {
            case updating
            case done
            case failed(FailureReason)
        }
    }
}

// MARK: - Feedbacks

extension MergeService {
    fileprivate typealias Feedbacks = MergeService

    fileprivate static func whenAddingPullRequests(
        github: GitHubAPIProtocol,
        scheduler: Scheduler
    ) -> Feedback<State, Event> {

        return Feedback(
            deriving: { state in state.combinePrevious() },
            effects: { previous, current -> SignalProducer<Event, NoError> in

                let actions = current.pullRequests
                    .enumerated()
                    .map { index, pullRequest -> SignalProducer<(), NoError> in

                        guard previous.status == .starting || previous.pullRequests.firstIndex(of: pullRequest) == nil
                            else { return .empty }

                        if index == 0 && current.isIntegrationOngoing == false {
                            return github.postComment(
                                "Your pull request was accepted and is going to be handled right away 🏎",
                                in: pullRequest
                            )
                            .flatMapError { _ in .empty }
                        } else {
                            return github.postComment(
                                "Your pull request was accepted and it's currently `#\(index + 1)` in the `\(current.targetBranch)` queue, hold tight ⏳",
                                in: pullRequest
                            )
                            .flatMapError { _ in .empty }
                        }
                }

                return SignalProducer.merge(actions)
                    .then(.empty)
        })
    }

    fileprivate static func whenStarting(initialPullRequests: [PullRequest], scheduler: DateScheduler) -> Feedback<State, Event> {
        return Feedback(predicate: { $0.status == .starting }) { state -> SignalProducer<Event, NoError> in
            return SignalProducer
                .value(Event.pullRequestsLoaded(initialPullRequests))
                .observe(on: scheduler)
        }
    }

    fileprivate static func whenReady(github: GitHubAPIProtocol, scheduler: Scheduler) -> Feedback<State, Event> {
        return Feedback(predicate: { $0.status == .ready }) { state -> SignalProducer<Event, NoError> in

            guard let next = state.pullRequests.first else {
                return SignalProducer
                    .value(.noMorePullRequests)
                    .observe(on: scheduler)
            }

            // Refresh pull request to ensure an up-to-date state
            return github.fetchPullRequest(number: next.number)
                .flatMapError { _ in .empty }
                .map(Event.integrate)
                .observe(on: scheduler)
        }
    }

    fileprivate static func whenIntegrating(
        github: GitHubAPIProtocol,
        requiresAllStatusChecks: Bool,
        pullRequestChanges: Signal<(PullRequestMetadata, PullRequest.Action), NoError>,
        scheduler: DateScheduler
    ) -> Feedback<State, Event> {

        enum IntegrationError: Error {
            case stateCouldNotBeDetermined
            case synchronizationFailed
        }

        return Feedback(skippingRepeated: { $0.status.integrationMetadata }) { metadata -> SignalProducer<Event, NoError> in

            guard metadata.isMerged == false
                else { return .value(.integrationDidChangeStatus(.done, metadata)) }

            switch metadata.mergeState {
            case .clean,
                 .unstable where !requiresAllStatusChecks:
                return github.mergePullRequest(metadata.reference)
                    .flatMap(.latest) { () -> SignalProducer<(), NoError> in
                        github.deleteBranch(named: metadata.reference.source)
                            .flatMapError { _ in .empty }
                    }
                    .then(SignalProducer<Event, NoError>.value(Event.integrationDidChangeStatus(.done, metadata)))
                    .flatMapError { _ in .value(Event.integrationDidChangeStatus(.failed(.mergeFailed), metadata)) }
                    .observe(on: scheduler)
            case .behind:
                return github.merge(head: metadata.reference.target, into: metadata.reference.source)
                    .flatMap(.latest) { result -> SignalProducer<Event, AnyError> in
                        switch result {
                        case .success:
                            return pullRequestChanges.filter { changedMetadata, action in
                                    action == .synchronize
                                        && changedMetadata.reference.source.ref == metadata.reference.source.ref
                                }
                                .producer
                                .take(first: 1)
                                .map { changedMetadata, _ in
                                    Event.integrationDidChangeStatus(.updating, changedMetadata)
                                }
                                .promoteError()
                                .timeout(
                                    after: 60.0,
                                    raising: AnyError(IntegrationError.synchronizationFailed), on: scheduler
                                )
                        case .upToDate:
                            return .value(.integrationDidChangeStatus(.updating, metadata))
                        case .conflict:
                            return .value(.integrationDidChangeStatus(.failed(.conflicts), metadata))
                        }
                    }
                    .flatMapError { _ in .value(.integrationDidChangeStatus(.failed(.synchronizationFailed), metadata)) }
                    .observe(on: scheduler)
            case .blocked,
                 .unstable:
                let pullRequest = metadata.reference
                return github.fetchAllStatusChecks(for: pullRequest).map { statusChecks -> Bool in
                    return statusChecks.map({ $0.state }).contains(.pending)
                }.flatMap(.latest) { pendingStatusChecks -> SignalProducer<Event, AnyError> in
                    if pendingStatusChecks {
                        return .value(.integrationDidChangeStatus(.updating, metadata))
                    } else {
                        return github.fetchCommitStatus(for: metadata.reference)
                            .flatMap(.latest) { commitStatus -> SignalProducer<Event, AnyError> in
                                switch commitStatus.state {
                                case .pending:
                                    return .value(.integrationDidChangeStatus(.updating, metadata))
                                case .failure:
                                    return .value(.integrationDidChangeStatus(.failed(.checksFailing), metadata))
                                case  .success:
                                    return github.fetchPullRequest(number: metadata.reference.number)
                                        .map { metadata in
                                            switch metadata.mergeState {
                                            case .clean:
                                                return .retryIntegration(metadata)
                                            default:
                                                return .integrationDidChangeStatus(.failed(.blocked), metadata)
                                            }
                                    }
                            }
                        }
                        .observe(on: scheduler)
                    }
                }
                .flatMapError { _ in .value(Event.integrationDidChangeStatus(.failed(.checkingCommitChecksFailed), metadata)) }
                .observe(on: scheduler)
            case .dirty:
                return SignalProducer(value: Event.integrationDidChangeStatus(.failed(.conflicts), metadata))
                    .observe(on: scheduler)
            case .unknown:
                return SignalProducer<Event, IntegrationError> { observer, _ in
                    github.fetchPullRequest(number: metadata.reference.number)
                        .take(first: 1)
                        .startWithResult {
                            switch $0 {
                            case let .success(metadata):
                                if metadata.mergeState == .unknown {
                                    observer.send(error: IntegrationError.stateCouldNotBeDetermined)
                                } else {
                                    observer.send(value: Event.retryIntegration(metadata))
                                    observer.sendCompleted()
                                }
                            case .failure:
                                observer.send(error: IntegrationError.stateCouldNotBeDetermined)
                            }
                        }
                    }
                    .retry(upTo: 4, interval: 30.0, on: scheduler)
                    .flatMapError { _ in .value(Event.integrationDidChangeStatus(.failed(.unknown), metadata)) }
                    .observe(on: scheduler)
            }
        }
    }

    fileprivate static func whenRunningStatusChecks(
        github: GitHubAPIProtocol,
        logger: LoggerProtocol,
        requiresAllStatusChecks: Bool,
        statusChecksCompletion: Signal<StatusEvent, NoError>,
        scheduler: DateScheduler
    ) -> Feedback<State, Event> {

        struct Context: Equatable {
            let pullRequestMetadata: PullRequestMetadata
            let statusChecksTimeout: TimeInterval

            init?(state: State) {
                guard let metadata = state.status.statusChecksMetadata
                    else { return nil }

                self.pullRequestMetadata = metadata
                self.statusChecksTimeout = state.statusChecksTimeout
            }
        }

        return Feedback(skippingRepeated: Context.init) { context -> Signal<Event, NoError> in

            enum TimeoutError: Error {
                case timedOut
            }

            let pullRequest = context.pullRequestMetadata.reference

            return statusChecksCompletion
                .observe(on: scheduler)
                .filter { change in change.state != .pending && change.isRelative(toBranch: pullRequest.source.ref) }
                .on { change in
                    logger.log("📣 Status check `\(change.context)` finished with result: `\(change.state)` (SHA: `\(change.sha)`)")
                }
                // Checks can complete and lead to new checks which can be included posteriorly leading to a small time
                // window where all checks have passed but just until the next check is added and starts running. This
                // hopefully prevents those false positives by making sure we wait some time before checking if all
                // checks have passed
                .debounce(60.0, on: scheduler)
                .flatMap(.latest) { change in
                    github.fetchPullRequest(number: pullRequest.number)
                        .flatMap(.latest) { github.fetchCommitStatus(for: $0.reference).zip(with: .value($0)) }
                        .flatMap(.latest) { commitStatus, pullRequestMetadataRefreshed -> SignalProducer<(CommitState.State, PullRequestMetadata), AnyError> in
                            let requiredStateProducer = requiresAllStatusChecks
                                ? .value(commitStatus.state)
                                : getRequiredChecksState(github: github, targetBranch: pullRequest.target, commitState: commitStatus)
                            return requiredStateProducer.zip(with: .value(pullRequestMetadataRefreshed))
                        }
                        .flatMapError { _ in .empty }
                        .filterMap { state, pullRequestMetadataRefreshed in
                            switch state {
                            case .pending:
                                return nil
                            case .failure:
                                return .statusChecksDidComplete(.failed(pullRequestMetadataRefreshed))
                            case .success:
                                return .statusChecksDidComplete(.passed(pullRequestMetadataRefreshed))
                            }
                    }
                }
                .timeout(after: context.statusChecksTimeout, raising: TimeoutError.timedOut, on: scheduler)
                .flatMapError { error in
                    switch error {
                    case .timedOut: return .value(.statusChecksDidComplete(.timedOut(context.pullRequestMetadata)))
                    }
                }
        }
    }

    fileprivate static func whenIntegrationFailed(
        github: GitHubAPIProtocol,
        logger: LoggerProtocol,
        scheduler: Scheduler
    ) -> Feedback<State, Event> {

        struct IntegrationHandler: Equatable {
            let pullRequest: PullRequest
            let integrationLabel: PullRequest.Label
            let failureReason: FailureReason

            var failureMessage: String {
                return "@\(pullRequest.author.login) unfortunately the integration failed with code: `\(failureReason)`."
            }

            init?(from state: State) {
                guard case let .integrationFailed(metadata, reason) = state.status
                    else { return nil }
                self.pullRequest = metadata.reference
                self.integrationLabel = state.integrationLabel
                self.failureReason = reason
            }
        }

        return Feedback(skippingRepeated: IntegrationHandler.init) { handler -> SignalProducer<Event, NoError> in
            return SignalProducer.merge(
                github.postComment(handler.failureMessage, in: handler.pullRequest)
                    .on(failed: { error in logger.log("🚨 Failed to post failure message in PR #\(handler.pullRequest.number) with error: \(error)") }),
                github.removeLabel(handler.integrationLabel, from: handler.pullRequest)
                    .on(failed: { error in logger.log("🚨 Failed to remove integration label from PR #\(handler.pullRequest.number) with error: \(error)") })
                )
                .flatMapError { _ in .empty }
                .then(SignalProducer(value: Event.integrationFailureHandled))
                .observe(on: scheduler)
        }
    }

    fileprivate static func pullRequestChanges(
        pullRequestChanges: Signal<(PullRequestMetadata, PullRequest.Action), NoError>,
        scheduler: Scheduler
    ) -> Feedback<State, Event> {
        return Feedback(predicate: { $0.status != .starting }) { state in
            return pullRequestChanges
                .observe(on: scheduler)
                .filterMap { metadata, action in
                    eventOutcome(metadata: metadata, action: action, integrationLabel: state.integrationLabel)
                }
                .map(Event.pullRequestDidChange)
        }
    }

    /// Returns the consolidated status of all _required_ checks only
    /// i.e. returns .failure or .pending if one of the required check is in .failure or .pending respectively
    /// and return .success only if all required states are .success
    fileprivate static func getRequiredChecksState(
        github: GitHubAPIProtocol,
        targetBranch: PullRequest.Branch,
        commitState: CommitState
    ) -> SignalProducer<CommitState.State, AnyError> {
        if commitState.state == .success {
            return .value(.success)
        }
        return github.fetchRequiredStatusChecks(for: targetBranch).map { (requiredStatusChecks) -> CommitState.State in
            let requiredStates = requiredStatusChecks.contexts.map { requiredContext in
                commitState.statuses.first(where: { $0.context == requiredContext })?.state ?? .pending
            }
            return CommitState.State.combinedState(for: requiredStates)
        }
    }
}

// MARK: - Reducers

extension MergeService.State {

    fileprivate typealias Event = MergeService.Event

    fileprivate func reduceIdle(with event: Event) -> MergeService.State? {
        switch event {
        case let .pullRequestDidChange(.include(pullRequest)):
            return self.with(status: .ready).include(pullRequests: [pullRequest])
        default:
            return nil
        }
    }

    fileprivate func reduceStarting(with event: Event) -> MergeService.State? {
        switch event {
        case let .pullRequestsLoaded(pullRequests) where pullRequests.isEmpty == true:
            return self.with(status: .idle)
        case let .pullRequestsLoaded(pullRequests) where pullRequests.isEmpty == false:
            return self.with(status: .ready).include(pullRequests: pullRequests)
        default:
            return nil
        }
    }

    fileprivate func reduceReady(with event: Event) -> MergeService.State? {
        switch event {
        case .noMorePullRequests:
            return self.with(status: .idle)
        case let .integrate(metadata):
            return self.with(status: .integrating(metadata)).exclude(pullRequest: metadata.reference)
        default:
            return nil
        }
    }

    fileprivate func reduceIntegrating(with metadata: PullRequestMetadata, event: Event) -> MergeService.State? {
        switch event {
        case .integrationDidChangeStatus(.done, _):
            return self.with(status: .ready)
        case let .integrationDidChangeStatus(.failed(reason), metadata):
            return self.with(status: .integrationFailed(metadata, reason))
        case let .integrationDidChangeStatus(.updating, metadata):
            return self.with(status: .runningStatusChecks(metadata))
        case let .pullRequestDidChange(.exclude(pullRequestExcluded)) where metadata.reference.number == pullRequestExcluded.number:
            return self.with(status: .ready)
        case let .retryIntegration(metadata):
            return self.with(status: .integrating(metadata))
        default:
            return nil
        }
    }

    fileprivate func reduceRunningStatusChecks(with metadata: PullRequestMetadata, event: Event) -> MergeService.State? {
        switch event {
        case let .statusChecksDidComplete(.passed(pullRequest)):
            return self.with(status: .integrating(pullRequest))
        case let .statusChecksDidComplete(.failed(pullRequest)):
            return self.with(status: .integrationFailed(pullRequest, .checksFailing))
        case let .statusChecksDidComplete(.timedOut(pullRequest)):
            return self.with(status: .integrationFailed(pullRequest, .timedOut))
        case let .pullRequestDidChange(.exclude(pullRequestExcluded)) where metadata.reference.number == pullRequestExcluded.number:
            return self.with(status: .ready)
        default:
            return nil
        }
    }

    fileprivate func reduceIntegrationFailed(with event: Event) -> MergeService.State? {
        switch event {
        case .integrationFailureHandled:
            return self.with(status: .ready)
        default:
            return nil
        }
    }

    fileprivate func reduceDefault(with event: Event) -> MergeService.State {
        switch event {
        case let .pullRequestDidChange(.include(pullRequest)):
            return self.with(status: status).include(pullRequests: [pullRequest])
        case let .pullRequestDidChange(.exclude(pullRequest)):
            return self.with(status: status).exclude(pullRequest: pullRequest)
        default:
            return self
        }
    }
}

// MARK: - Healthcheck

extension MergeService {
    public final class Healthcheck {
        public let status: Property<Status>

        public enum Reason: Error, Equatable {
            case potentialDeadlock
        }

        public enum Status: Equatable {
            case ok
            case unhealthy(Reason)
        }

        internal init(
            state: Signal<State, NoError>,
            statusChecksTimeout: TimeInterval,
            scheduler: DateScheduler
        ) {
            status = Property(
                initial: .ok,
                then: state.combinePrevious()
                    // Can't just use skipRepeats() as (at least as of Swift 4), tuple of Equatable is not itself Equatable
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

// MARK: - Helpers

fileprivate func eventOutcome(
    metadata: PullRequestMetadata,
    action: PullRequest.Action,
    integrationLabel: PullRequest.Label
) -> MergeService.State.Event.Outcome? {
    switch action {
    case .opened where metadata.reference.isLabelled(with: integrationLabel):
        return .include(metadata.reference)
    case .labeled where metadata.reference.isLabelled(with: integrationLabel) && metadata.isMerged == false:
        return .include(metadata.reference)
    case .unlabeled where metadata.reference.isLabelled(with: integrationLabel) == false:
        return .exclude(metadata.reference)
    case .closed:
        return .exclude(metadata.reference)
    default:
        return nil
    }
}

extension MergeService.State: CustomStringConvertible {

    private var queueDescription: String {
        guard pullRequests.isEmpty == false else { return "[]" }

        let pullRequestsSeparator = "\n\t\t"

        let pullRequestsRepresentation = pullRequests.enumerated().map { index, pullRequest in
            let isTP = pullRequest.isLabelled(withOneOf: self.topPriorityLabels)
            return "#\(index + 1): \(pullRequest) \(isTP ? "[TP]" : "")"
        }.joined(separator: pullRequestsSeparator)

        return "\(pullRequestsSeparator)\(pullRequestsRepresentation)"
    }

    public var description: String {
        return "State(\n - status: \(status),\n - queue: \(queueDescription)\n)"
    }
}

extension MergeService.State: Encodable {
    enum CodingKeys: String, CodingKey {
        case targetBranch
        case status
        case queue
    }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)

        try values.encode(targetBranch, forKey: .targetBranch)
        try values.encode(status, forKey: .status)
        try values.encode(pullRequests, forKey: .queue)
    }
}

extension SignalProducer {

    static func value(_ value: Value) -> SignalProducer<Value, Error> {
        return SignalProducer(value: value)
    }

    static func error(_ error: Error) -> SignalProducer<Value, Error> {
        return SignalProducer(error: error)
    }
}

extension Int {
    public var minutes: TimeInterval {
        return Double(self) * 60
    }
}
