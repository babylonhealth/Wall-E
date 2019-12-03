import ReactiveSwift
import Result

// TODO: Refactor interface
public protocol GitHubAPIProtocol {

    func fetchPullRequests() -> SignalProducer<[PullRequest], AnyError>

    func fetchPullRequest(number: UInt) -> SignalProducer<PullRequestMetadata, AnyError>

    func fetchCommitStatus(for pullRequest: PullRequest) -> SignalProducer<CommitState, AnyError>

    func fetchRequiredStatusChecks(for branch: PullRequest.Branch) -> SignalProducer<RequiredStatusChecks, AnyError>

    func fetchAllStatusChecks(for pullRequest: PullRequest) -> SignalProducer<[PullRequest.StatusCheck], AnyError>

    /// Merges one branch into another.
    ///
    /// - SeeAlso: https://developer.github.com/v3/repos/merging/
    func merge(head: PullRequest.Branch, into base: PullRequest.Branch) -> SignalProducer<MergeResult, AnyError>

    /// Merges an open pull request.
    ///
    /// - Note: This mimics the `Merge Button` from GitHub UI.
    ///
    /// - SeeAlso: https://developer.github.com/v3/pulls/#merge-a-pull-request-merge-button
    func mergePullRequest(_ pullRequest: PullRequest) -> SignalProducer<Void, AnyError>

    func deleteBranch(named branch: PullRequest.Branch) -> SignalProducer<Void, AnyError>

    func postComment(_ comment: String, in pullRequest: PullRequest) -> SignalProducer<Void, AnyError>

    func removeLabel(_ label: PullRequest.Label, from pullRequest: PullRequest) -> SignalProducer<Void, AnyError>
}
