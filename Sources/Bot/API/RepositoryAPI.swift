import Foundation
import ReactiveSwift

public struct RepositoryAPI: GitHubAPIProtocol {
    private let client: GitHubClient
    private let repository: Repository

    public init(client: GitHubClient, repository: Repository) {
        self.client = client
        self.repository = repository
    }

    public func fetchPullRequests() -> SignalProducer<[PullRequest], GitHubClient.Error> {
        return client.request(repository.pullRequests)
            // Ensure we group all pages into a single list containing all pull requests
            .flatten()
            .collect()
    }

    public func fetchPullRequest(number: UInt) -> SignalProducer<PullRequestMetadata, GitHubClient.Error> {
        return client.request(repository.pullRequest(number: number))
    }

    public func fetchCommitStatus(for pullRequest: PullRequest) -> SignalProducer<CommitState, GitHubClient.Error> {
        return client.request(repository.commitStatus(for: pullRequest))
    }

    public func fetchRequiredStatusChecks(for branch: PullRequest.Branch) -> SignalProducer<RequiredStatusChecks, GitHubClient.Error> {
        return client.request(repository.requiredStatusChecks(branch: branch))
    }

    public func fetchAllStatusChecks(for pullRequest: PullRequest) -> SignalProducer<[PullRequest.StatusCheck], GitHubClient.Error> {
        return client.request(repository.allStatusChecks(for: pullRequest))
    }

    public func merge(head: PullRequest.Branch, into base: PullRequest.Branch) -> SignalProducer<MergeResult, GitHubClient.Error> {
        return client.request(repository.merge(head: head, into: base))
    }

    public func mergePullRequest(_ pullRequest: PullRequest) -> SignalProducer<Void, GitHubClient.Error> {
        return client.request(repository.merge(pullRequest: pullRequest))
    }

    public func deleteBranch(named branch: PullRequest.Branch) -> SignalProducer<Void, GitHubClient.Error> {
        return client.request(repository.deleteBranch(branch: branch))
    }

    public func postComment(_ comment: String, in pullRequest: PullRequest) -> SignalProducer<Void, GitHubClient.Error> {
        return client.request(repository.publish(comment: comment, in: pullRequest))
    }

    public func fetchIssueComments(in pullRequest: PullRequest) -> SignalProducer<[IssueComment], GitHubClient.Error> {
        return client.request(repository.issueComments(in: pullRequest))
    }

    public func removeLabel(_ label: PullRequest.Label, from pullRequest: PullRequest) -> SignalProducer<Void, GitHubClient.Error> {
        return client.request(repository.removeLabel(label: label, from: pullRequest))
    }

    public func fetchCurrentUser() -> SignalProducer<GitHubUser, GitHubClient.Error> {
        return client.request(repository.currentUser)
    }
}

extension GitHubClient {

    public func api(for repository: Repository) -> RepositoryAPI {
        return RepositoryAPI(client: self, repository: repository)
    }
}
