import Foundation
import ReactiveSwift
import Result

public struct RepositoryAPI: GitHubAPIProtocol {
    private let client: GitHubClient
    private let repository: Repository

    public init(client: GitHubClient, repository: Repository) {
        self.client = client
        self.repository = repository
    }

    public func fetchPullRequests() -> SignalProducer<[PullRequest], AnyError> {
        return client.request(repository.pullRequests)
            // Ensure we group all pages into a single list containing all pull requests
            .flatten()
            .collect()
            .mapError(AnyError.init)
    }

    public func fetchPullRequest(number: UInt) -> SignalProducer<PullRequestMetadata, AnyError> {
        return client.request(repository.pullRequest(number: number))
            .mapError(AnyError.init)
    }

    public func fetchCommitStatus(for pullRequest: PullRequest) -> SignalProducer<CommitState, AnyError> {
        return client.request(repository.commitStatus(for: pullRequest))
            .mapError(AnyError.init)
    }

    public func fetchRequiredStatusChecks(for branch: PullRequest.Branch) -> SignalProducer<RequiredStatusChecks, AnyError> {
        return client.request(repository.requiredStatusChecks(branch: branch))
            .mapError(AnyError.init)
    }

    public func merge(head: PullRequest.Branch, into base: PullRequest.Branch) -> SignalProducer<MergeResult, AnyError> {
        return client.request(repository.merge(head: head, into: base))
            .mapError(AnyError.init)
    }

    public func mergePullRequest(_ pullRequest: PullRequest) -> SignalProducer<Void, AnyError> {
        return client.request(repository.merge(pullRequest: pullRequest))
            .mapError(AnyError.init)
    }

    public func deleteBranch(named branch: PullRequest.Branch) -> SignalProducer<Void, AnyError> {
        return client.request(repository.deleteBranch(branch: branch))
            .mapError(AnyError.init)
    }

    public func postComment(_ comment: String, in pullRequest: PullRequest) -> SignalProducer<Void, AnyError> {
        return client.request(repository.publish(comment: comment, in: pullRequest))
            .mapError(AnyError.init)
    }

    public func removeLabel(_ label: PullRequest.Label, from pullRequest: PullRequest) -> SignalProducer<Void, AnyError> {
        return client.request(repository.removeLabel(label: label, from: pullRequest))
            .mapError(AnyError.init)
    }
}

extension GitHubClient {

    public func api(for repository: Repository) -> RepositoryAPI {
        return RepositoryAPI(client: self, repository: repository)
    }
}
