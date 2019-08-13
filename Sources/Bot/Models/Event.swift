import Foundation

public enum Event: Equatable {
    case pullRequest(PullRequestEvent)
    case status(StatusChange)
    case ping
}

// MARK: - Pull Request Event

public struct PullRequestEvent: Equatable {
    public let action: PullRequest.Action
    public let pullRequestMetadata: PullRequestMetadata
}

extension PullRequestEvent: Decodable {
    enum CodingKeys: String, CodingKey {
        case action
        case pullRequestMetadata = "pull_request"
    }
}
