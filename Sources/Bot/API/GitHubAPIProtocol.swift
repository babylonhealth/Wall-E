import ReactiveSwift

// TODO: Refactor interface
public protocol GitHubAPIProtocol {

    func fetchPullRequests() -> SignalProducer<[PullRequest], GitHubClient.Error>

    func fetchPullRequest(number: UInt) -> SignalProducer<PullRequestMetadata, GitHubClient.Error>

    func fetchCommitStatus(for pullRequest: PullRequest) -> SignalProducer<CommitState, GitHubClient.Error>

    func fetchRequiredStatusChecks(for branch: PullRequest.Branch) -> SignalProducer<RequiredStatusChecks, GitHubClient.Error>

    func fetchAllStatusChecks(for pullRequest: PullRequest) -> SignalProducer<[PullRequest.StatusCheck], GitHubClient.Error>

    /// Merges one branch into another.
    ///
    /// - SeeAlso: https://developer.github.com/v3/repos/merging/
    func merge(head: PullRequest.Branch, into base: PullRequest.Branch) -> SignalProducer<MergeResult, GitHubClient.Error>

    /// Merges an open pull request.
    ///
    /// - Note: This mimics the `Merge Button` from GitHub UI.
    ///
    /// - SeeAlso: https://developer.github.com/v3/pulls/#merge-a-pull-request-merge-button
    func mergePullRequest(_ pullRequest: PullRequest) -> SignalProducer<Void, GitHubClient.Error>

    func deleteBranch(named branch: PullRequest.Branch) -> SignalProducer<Void, GitHubClient.Error>

    func postComment(_ comment: String, in pullRequest: PullRequest) -> SignalProducer<Void, GitHubClient.Error>

    /// Note: only fetches issue comments, not Pull Request review comments
    func fetchIssueComments(in pullRequest: PullRequest) -> SignalProducer<[IssueComment], GitHubClient.Error>

    func removeLabel(_ label: PullRequest.Label, from pullRequest: PullRequest) -> SignalProducer<Void, GitHubClient.Error>

    func fetchCurrentUser() -> SignalProducer<GitHubUser, GitHubClient.Error>
}
