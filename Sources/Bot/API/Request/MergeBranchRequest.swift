import Foundation

struct MergeBranchRequest: Encodable {
    let base: String
    let head: String
    // TODO: Add commit message

    init(base: PullRequest.Branch, head: PullRequest.Branch) {
        self.base = base.ref
        self.head = head.ref
    }
}
