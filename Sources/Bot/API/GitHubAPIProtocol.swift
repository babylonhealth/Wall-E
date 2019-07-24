import ReactiveSwift
import Result

public protocol GitHubAPIProtocol {

    func fetchPullRequests() -> SignalProducer<[PullRequest], AnyError>

    func fetchPullRequest(number: UInt) -> SignalProducer<PullRequestMetadata, AnyError>

    func fetchCommitStatus(for pullRequest: PullRequest) -> SignalProducer<CommitStatus, AnyError>

    func merge(intoBranch branch: String, head: String) -> SignalProducer<MergeResult, AnyError>

    func mergePullRequest(_ pullRequest: PullRequest) -> SignalProducer<(), AnyError>

    func deleteBranch(named branch: String) -> SignalProducer<(), AnyError>

    func postComment(_ comment: String, inPullRequestNumber pullRequestNumber: UInt) -> SignalProducer<(), AnyError>

    func removeLabel(_ label: String, fromPullRequestNumber pullRequestNumber: UInt) -> SignalProducer<(), AnyError>
}
