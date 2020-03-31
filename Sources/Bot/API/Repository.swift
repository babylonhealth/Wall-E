//
//  Repository.swift
//  Bot
//
//  Created by David Rodrigues on 06/08/2019.
//

import Foundation

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
            decoder: decode
        )
    }

    func pullRequest(number: UInt) -> Resource<PullRequestMetadata> {
        return Resource(method: .GET, path: path(for: "pulls/\(number)"), decoder: decode)
    }

    func commitStatus(for pullRequest: PullRequest) -> Resource<CommitState> {
        return Resource(
            method: .GET,
            path: path(for: "commits/\(pullRequest.source.sha)/status"),
            decoder: decode
        )
    }

    func requiredStatusChecks(branch: PullRequest.Branch) -> Resource<RequiredStatusChecks> {
        return Resource(
            method: .GET,
            path: path(for: "branches/\(branch.ref)/protection/required_status_checks"),
            decoder: decode
        )
    }

    func allStatusChecks(for pullRequest: PullRequest) -> Resource<[PullRequest.StatusCheck]> {
        return Resource(
            method: .GET,
            path: path(for: "commits/\(pullRequest.source.sha)/statuses"),
            decoder: decode
        )
    }

    func deleteBranch(branch: PullRequest.Branch) -> Resource<Void> {
        return Resource(
            method: .DELETE,
            path: path(for: "git/refs/heads/\(branch.ref)"),
            decoder: decode
        )
    }

    func removeLabel(label: PullRequest.Label, from pullRequest: PullRequest) -> Resource<Void> {
        return Resource(
            method: .DELETE,
            path: path(for: "issues/\(pullRequest.number)/labels/\(label.name)"),
            decoder: decode
        )
    }

    func publish(comment: String, in pullRequest: PullRequest) -> Resource<Void> {
        return Resource(
            method: .POST,
            path: path(for: "issues/\(pullRequest.number)/comments"),
            body: encode(PostCommmentRequest(body: comment)),
            decoder: decode
        )
    }

    func issueComments(in pullRequest: PullRequest) -> Resource<[IssueComment]> {
        return Resource(
            method: .GET,
            path: path(for: "issues/\(pullRequest.number)/comments"),
            decoder: decode
        )
    }

    func merge(head: PullRequest.Branch, into base: PullRequest.Branch) -> Resource<MergeResult> {
        return Resource(
            method: .POST,
            path: path(for: "merges"),
            body: encode(MergeBranchRequest(base: base, head: head)),
            decoder: { response in
                switch response.statusCode {
                case 201: return .success(.success)
                case 204: return .success(.upToDate)
                case 409: return .success(.conflict)
                default:
                    return .failure(.api(response))
                }
            }
        )
    }

    func merge(pullRequest: PullRequest) -> Resource<Void> {
        return Resource(
            method: .PUT,
            path: path(for: "pulls/\(pullRequest.number)/merge"),
            body: encode(MergePullRequestRequest(with: pullRequest)),
            decoder: decode
        )
    }

    var currentUser: Resource<GitHubUser> {
        Resource(
            method: .GET,
            path: "user",
            decoder: decode
        )
    }

    // TODO: This should be moved to be done as part of the handling of resources in `GitHubClient`
    private func encode<T: Encodable>(_ t: T) -> Data {
        guard let data = try? JSONEncoder().encode(t)
            else { fatalError("Unexpected failure while encoding `\(t)`") }

        return data
    }
}
