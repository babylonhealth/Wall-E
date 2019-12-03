@testable import Bot

extension PullRequestMetadata {

    static func stub(
        number: UInt,
        headRef: String = "abcdef",
        baseRef: String = "master",
        labels: [PullRequest.Label] = [],
        mergeState: PullRequestMetadata.MergeState = .clean
    ) -> PullRequestMetadata {
        return PullRequestMetadata(
            reference: PullRequest(
                number: number,
                title: "Best Pull Request",
                author: .init(login: "John Doe"),
                source: .init(ref: headRef, sha: "abcdef"),
                target: .init(ref: baseRef, sha: "abc"),
                labels: labels
            ),
            isMerged: false,
            mergeState: mergeState
        )
    }

    func with(mergeState: MergeState) -> PullRequestMetadata {
        return PullRequestMetadata(
            reference: PullRequest(
                number: reference.number,
                title: reference.title,
                author: reference.author,
                source: reference.source,
                target: reference.target,
                labels: reference.labels
            ),
            isMerged: isMerged,
            mergeState: mergeState
        )
    }

    func with(labels: [PullRequest.Label]) -> PullRequestMetadata {
        return PullRequestMetadata(
            reference: PullRequest(
                number: reference.number,
                title: reference.title,
                author: reference.author,
                source: reference.source,
                target: reference.target,
                labels: labels
            ),
            isMerged: isMerged,
            mergeState: mergeState
        )
    }
}
