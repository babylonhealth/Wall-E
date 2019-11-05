import Foundation
import ReactiveSwift
import Result
import Nimble
@testable import Bot

struct MockGitHubAPI: GitHubAPIProtocol {

    enum Stubs {
        case getPullRequests(() -> [PullRequest])
        case getPullRequest((UInt) -> PullRequestMetadata)
        case getCommitStatus((PullRequest) -> CommitState)
        case getRequiredStatusChecks((PullRequest.Branch) -> RequiredStatusChecks)
        case mergePullRequest((PullRequest) -> Void)
        case mergeIntoBranch((PullRequest.Branch, PullRequest.Branch) -> MergeResult)
        case deleteBranch((PullRequest.Branch) -> Void)
        case postComment((String, PullRequest) -> Void)
        case removeLabel((PullRequest.Label, PullRequest) -> Void)
    }

    let stubs: [Stubs]

    private let stubCount = Atomic(0)

    func assert() -> Bool {
        return stubCount.value == stubs.count
    }

    func fetchPullRequests() -> SignalProducer<[PullRequest], AnyError> {
        switch nextStub() {
        case let .getPullRequests(handler):
            return SignalProducer(value: handler())
        default:
            fatalError("Stub not found")
        }
    }

    func fetchPullRequest(number: UInt) -> SignalProducer<PullRequestMetadata, AnyError> {
        switch nextStub() {
        case let .getPullRequest(handler):
            return SignalProducer(value: handler(number))
        default:
            fatalError("Stub not found")
        }
    }

    func fetchCommitStatus(for pullRequest: PullRequest) -> SignalProducer<CommitState, AnyError> {
        switch nextStub() {
        case let .getCommitStatus(handler):
            return SignalProducer(value: handler(pullRequest))
        default:
            fatalError("Stub not found")
        }
    }

    func fetchRequiredStatusChecks(for branch: PullRequest.Branch) -> SignalProducer<RequiredStatusChecks, AnyError> {
        switch nextStub() {
        case let .getRequiredStatusChecks(handler):
            return SignalProducer(value: handler(branch))
        default:
            fatalError("Stub not found")
        }
    }

    func merge(head: PullRequest.Branch, into base: PullRequest.Branch) -> SignalProducer<MergeResult, AnyError> {
        switch nextStub() {
        case let .mergeIntoBranch(handler):
            return SignalProducer(value: handler(base, head))
        default:
            fatalError("Stub not found")
        }
    }

    func mergePullRequest(_ pullRequest: PullRequest) -> SignalProducer<(), AnyError> {
        switch nextStub() {
        case let .mergePullRequest(handler):
            return SignalProducer(value: handler(pullRequest))
        default:
            fatalError("Stub not found")
        }
    }

    func deleteBranch(named branch: PullRequest.Branch) -> SignalProducer<(), AnyError> {
        switch nextStub() {
        case let .deleteBranch(handler):
            return SignalProducer(value: handler(branch))
        default:
            fatalError("Stub not found")
        }
    }

    func postComment(_ comment: String, in pullRequest: PullRequest) -> SignalProducer<(), AnyError> {
        switch nextStub() {
        case let .postComment(handler):
            return SignalProducer(value: handler(comment, pullRequest))
        default:
            fatalError("Stub not found")
        }
    }

    func removeLabel(_ label: PullRequest.Label, from pullRequest: PullRequest) -> SignalProducer<(), AnyError> {
        switch nextStub() {
        case let .removeLabel(handler):
            return SignalProducer(value: handler(label, pullRequest))
        default:
            fatalError("Stub not found")
        }
    }

    private func nextStub() -> Stubs {
        return stubCount.modify { stubCount -> Stubs in
            let nextStub = stubs[stubCount]
            stubCount = stubCount + 1
            return nextStub
        }
    }
}

