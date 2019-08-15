import Foundation

// TODO: This kind of data is tightly coupled with GitHub so we should move away from this model and make extra API calls to determine this states
public struct PullRequestMetadata: Equatable {
    let reference: PullRequest
    let isMerged: Bool
    let mergeState: MergeState
}

extension PullRequestMetadata {
    // NOTE: This is an undocumented property sent by the API which means can break in the future but is more
    // efficient than doing multiple checks to determine this
    //
    // Reference: https://github.com/octokit/octokit.net/pull/1764/files
    public enum MergeState: String, Decodable {
        /// Work in progress. Merging is blocked.
        case draft
        /// Merge conflict. Merging is blocked.
        case dirty
        /// Mergeability was not checked yet. Merging is blocked.
        case unknown
        /// Failing/missing required status check. Merging is blocked.
        case blocked
        /// Head branch is behind the base branch. Only if required status checks is enabled but loose policy is not. Merging is blocked.
        case behind
        /// Failing/pending commit status that is not part of the required status checks. Merging is still allowed.
        case unstable
        /// No conflicts, everything good. Merging is allowed.
        case clean
    }
}

extension PullRequestMetadata: Decodable {
    public init(from decoder: Decoder) throws {
        reference = try PullRequest(from: decoder)

        let container = try decoder.container(keyedBy: CodingKeys.self)

        isMerged = try container.decode(Bool.self, forKey: .isMerged)
        mergeState = try container.decode(PullRequestMetadata.MergeState.self, forKey: .mergeState)
    }

    enum CodingKeys: String, CodingKey {
        case isMerged = "merged"
        case mergeState = "mergeable_state"
    }
}

extension PullRequestMetadata: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "\(reference), isMerged: \(isMerged), mergeState: \(mergeState))"
    }
}
