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
            ],
            decoder: defaultDecoder
        )
    }

    func pullRequest(number: UInt) -> Resource<PullRequestMetadata> {
        return Resource(method: .GET, path: path(for: "pulls/\(number)"), decoder: defaultDecoder)
    }

    func commitStatus(for pullRequest: PullRequest) -> Resource<CommitState> {
        return Resource(
            method: .GET,
            path: path(for: "commits/\(pullRequest.source.sha)/status"),
            decoder: defaultDecoder
        )
    }

    func deleteBranch(branch: PullRequest.Branch) -> Resource<NoContent> {
        return Resource(
            method: .DELETE,
            path: path(for: "git/refs/heads/\(branch.ref)"),
            decoder: defaultDecoder
        )
    }

    func removeLabel(label: PullRequest.Label, from pullRequest: PullRequest) -> Resource<NoContent> {
        return Resource(
            method: .DELETE,
            path: path(for: "issues/\(pullRequest.number)/labels/\(label.name)"),
            decoder: defaultDecoder
        )
    }

    func publish(comment: String, in pullRequest: PullRequest) -> Resource<NoContent> {
        return Resource(
            method: .POST,
            path: path(for: "issues/\(pullRequest.number)/comments"),
            body: encode(PostCommmentRequest(body: comment)),
            decoder: defaultDecoder
        )
    }

    func performMerge(base: PullRequest.Branch, head: PullRequest.Branch) -> Resource<MergeResult> {
        return Resource(
            method: .POST,
            path: path(for: "merges"),
            body: encode(MergeBranchRequest(base: base, head: head)),
            decoder: { response in
                switch response.statusCode {
                case 200: return .success(.success)
                case 204: return .success(.upToDate)
                case 409: return .success(.conflict)
                default:
                    return .failure(.api(response))
                }
            }
        )
    }

    func merge(pullRequest: PullRequest) -> Resource<NoContent> {
        return Resource(
            method: .PUT,
            path: "pulls/\(pullRequest.number)/merge",
            body: encode(MergePullRequestRequest(with: pullRequest)),
            decoder: defaultDecoder
        )
    }

    private func defaultDecoder<T: Decodable>(_ response: Response) -> Result<T, GitHubClient.Error> {
        switch response.statusCode {
        case 200...299:
            return JSONDecoder.iso8601Decoder.decode(response.body)
                .mapError(GitHubClient.Error.decoding)
        default:
            return .failure(.api(response))
        }
    }

    // TODO: This should be moved to be done as part of the handling of resources in `GitHubClient`
    private func encode<T: Encodable>(_ t: T) -> Data {
        guard let data = try? JSONEncoder().encode(t)
            else { fatalError("Unexpected failure while encoding `\(t)`") }

        return data
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

    public func performMerge(base: PullRequest.Branch, head: PullRequest.Branch) -> SignalProducer<MergeResult, AnyError> {
        return client.request(repository.performMerge(base: base, head: head))
            .mapError(AnyError.init)
    }

    public func mergePullRequest(_ pullRequest: PullRequest) -> SignalProducer<(), AnyError> {
        return client.request(repository.merge(pullRequest: pullRequest))
            .mapError(AnyError.init)
    }

    public func deleteBranch(named branch: PullRequest.Branch) -> SignalProducer<(), AnyError> {
        return client.request(repository.deleteBranch(branch: branch))
            .map { _ in }
            .mapError(AnyError.init)
    }

    public func postComment(_ comment: String, in pullRequest: PullRequest) -> SignalProducer<(), AnyError> {
        return client.request(repository.publish(comment: comment, in: pullRequest))
            .map { _ in }
            .mapError(AnyError.init)
    }

    public func removeLabel(_ label: PullRequest.Label, from pullRequest: PullRequest) -> SignalProducer<(), AnyError> {
        return client.request(repository.removeLabel(label: label, from: pullRequest))
            .map { _ in }
            .mapError(AnyError.init)
    }
}
