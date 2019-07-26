import ReactiveSwift
import Result

// TODO: Refactor interface
public protocol GitHubAPIProtocol {

    func fetchPullRequests() -> SignalProducer<[PullRequest], AnyError>

    func fetchPullRequest(number: UInt) -> SignalProducer<PullRequestMetadata, AnyError>

    func fetchCommitStatus(for pullRequest: PullRequest) -> SignalProducer<CommitState, AnyError>

    func merge(intoBranch branch: String, head: String) -> SignalProducer<MergeResult, AnyError>

    func mergePullRequest(_ pullRequest: PullRequest) -> SignalProducer<(), AnyError>

    func deleteBranch(named branch: PullRequest.Branch) -> SignalProducer<(), AnyError>

    func postComment(_ comment: String, in pullRequest: PullRequest) -> SignalProducer<(), AnyError>

    func removeLabel(_ label: PullRequest.Label, from pullRequest: PullRequest) -> SignalProducer<(), AnyError>
}
