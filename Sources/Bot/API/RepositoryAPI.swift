import Foundation
import ReactiveSwift
import Result

public struct Repository: CustomStringConvertible {
    public let owner: String
    public let name: String

    public init(owner: String, name: String) {
        self.owner = owner
        self.name = name
    }

    public var description: String {
        return "\(owner)/\(name)"
    }
}

extension Repository {

    func path(for subPath: String) -> String {
        return "repos/\(self)/\(subPath)"
    }

    var pullRequests: Resource<[PullRequest]> {
        // TODO: The state should be defined by the consumer not us
        return Resource(
            method: .GET,
            path: path(for: "pulls"),
            queryItems: [
                URLQueryItem(name: "state", value: "open")
            ]
        )
    }

    func pullRequest(number: UInt) -> Resource<PullRequestMetadata> {
        return Resource(method: .GET, path: path(for: "pulls/\(number)"))
    }

    func commitStatus(for pullRequest: PullRequest) -> Resource<CommitState> {
        return Resource(
            method: .GET,
            path: path(for: "commits/\(pullRequest.source.sha)/status")
        )
    }

    func deleteBranch(branch: PullRequest.Branch) -> Resource<NoContent> {
        return Resource(
            method: .DELETE,
            path: path(for: "git/refs/heads/\(branch.ref)")
        )
    }
}

public struct RepositoryAPI: GitHubAPIProtocol {
    private let client: GitHubClient
    private let repository: Repository

    public init(client: GitHubClient, repository: Repository) {
        self.client = client
        self.repository = repository
    }

    public func fetchPullRequests() -> SignalProducer<[PullRequest], AnyError> {
        return client.request(repository.pullRequests)
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

    public func merge(intoBranch branch: String, head: String) -> SignalProducer<MergeResult, AnyError> {
        fatalError()
    }

    public func mergePullRequest(_ pullRequest: PullRequest) -> SignalProducer<(), AnyError> {
        fatalError()
    }

    public func deleteBranch(named branch: PullRequest.Branch) -> SignalProducer<(), AnyError> {
        return client.request(repository.deleteBranch(branch: branch))
            .map { _ in }
            .mapError(AnyError.init)
    }

    public func postComment(_ comment: String, inPullRequestNumber pullRequestNumber: UInt) -> SignalProducer<(), AnyError> {
        fatalError()
    }

    public func removeLabel(_ label: String, fromPullRequestNumber pullRequestNumber: UInt) -> SignalProducer<(), AnyError> {
        fatalError()
    }
}
