import Foundation
@testable import Bot

struct LabelFixture {
    static let integrationLabel = PullRequest.Label(name: "Please Merge 🙏")
    static let topPriorityLabels = [PullRequest.Label(name: "Top Priority 🚨"), PullRequest.Label(name: "HotFix 🚒")]
}

struct MergeServiceFixture {
    static let defaultStatusChecksTimeout = 30.minutes
    static let defaultIdleCleanupDelay = 10.minutes

    static let defaultBranch = "some-branch"
    static let defaultTargetBranch = "master"

    static let defaultTarget = PullRequestMetadata.stub(
        number: 1,
        headRef: MergeServiceFixture.defaultBranch,
        baseRef: MergeServiceFixture.defaultTargetBranch,
        labels: [LabelFixture.integrationLabel],
        mergeState: .behind
    )
}

// MARK: - Helpers

extension MergeService.State {
    static func stub(
        targetBranch: String = MergeServiceFixture.defaultTargetBranch,
        status: MergeService.State.Status,
        pullRequests: [PullRequest] = [],
        integrationLabel: PullRequest.Label = LabelFixture.integrationLabel,
        topPriorityLabels: [PullRequest.Label] = LabelFixture.topPriorityLabels,
        statusChecksTimeout: TimeInterval = MergeServiceFixture.defaultStatusChecksTimeout
    ) -> MergeService.State {
        return .init(
            targetBranch: targetBranch,
            integrationLabel: integrationLabel,
            topPriorityLabels: topPriorityLabels,
            statusChecksTimeout: statusChecksTimeout,
            pullRequests: pullRequests,
            status: status
        )
    }
}

extension ArraySlice {
    var asArray: [Element] {
        return Array(self)
    }
}

extension DispatchTimeInterval {
    static func minutes(_ value: Double) -> DispatchTimeInterval {
        return .seconds(Int(value) * 60)
    }
}
