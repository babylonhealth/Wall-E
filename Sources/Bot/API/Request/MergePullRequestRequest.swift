import Foundation

struct MergePullRequestRequest {
    let commitTitle: String
    let sha: String
    // TODO: This should be defined through a type
    let mergeMethod: String

    init(with pullRequest: PullRequest, method: String = "squash") {
        self.commitTitle = "\(pullRequest.title) (#\(pullRequest.number))"
        self.sha = pullRequest.source.sha
        self.mergeMethod = method
    }
}

extension MergePullRequestRequest: Encodable {
    private enum CodingKeys: String, CodingKey {
        case commitTitle = "commit_title"
        case sha
        case mergeMethod = "merge_method"
    }
}
