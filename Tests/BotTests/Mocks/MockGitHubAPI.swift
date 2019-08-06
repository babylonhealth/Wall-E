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
        case mergePullRequest((PullRequest) -> Void)
        case mergeIntoBranch((PullRequest.Branch, PullRequest.Branch) -> MergeResult)
        case deleteBranch((PullRequest.Branch) -> Void)
        case postComment((String, PullRequest) -> Void)
        case removeLabel((PullRequest.Label, PullRequest) -> Void)
    }

    let stubs: [Stubs]

    private let iteration = Atomic(0)

    func assert() -> Bool {
        return iteration.value == stubs.count
    }

    func fetchPullRequests() -> SignalProducer<[PullRequest], AnyError> {

        let index = iteration.modify { iteration -> Int in
            iteration = iteration + 1
            return iteration - 1
        }

        switch stubs[index] {
        case let .getPullRequests(handler):
            return SignalProducer(value: handler())
        default:
            fatalError("Stub not found")
        }
    }

    func fetchPullRequest(number: UInt) -> SignalProducer<PullRequestMetadata, AnyError> {

        let index = iteration.modify { iteration -> Int in
            iteration = iteration + 1
            return iteration - 1
        }

        switch stubs[index] {
        case let .getPullRequest(handler):
            return SignalProducer(value: handler(number))
        default:
            fatalError("Stub not found")
        }
    }

    func fetchCommitStatus(for pullRequest: PullRequest) -> SignalProducer<CommitState, AnyError> {

        let index = iteration.modify { iteration -> Int in
            iteration = iteration + 1
            return iteration - 1
        }

        switch stubs[index] {
        case let .getCommitStatus(handler):
            return SignalProducer(value: handler(pullRequest))
        default:
            fatalError("Stub not found")
        }
    }

    func merge(head: PullRequest.Branch, into base: PullRequest.Branch) -> SignalProducer<MergeResult, AnyError> {

        let index = iteration.modify { iteration -> Int in
            iteration = iteration + 1
            return iteration - 1
        }

        switch stubs[index] {
        case let .mergeIntoBranch(handler):
            return SignalProducer(value: handler(base, head))
        default:
            fatalError("Stub not found")
        }
    }

    func mergePullRequest(_ pullRequest: PullRequest) -> SignalProducer<(), AnyError> {

        let index = iteration.modify { iteration -> Int in
            iteration = iteration + 1
            return iteration - 1
        }

        switch stubs[index] {
        case let .mergePullRequest(handler):
            return SignalProducer(value: handler(pullRequest))
        default:
            fatalError("Stub not found")
        }
    }

    func deleteBranch(named branch: PullRequest.Branch) -> SignalProducer<(), AnyError> {

        let index = iteration.modify { iteration -> Int in
            iteration = iteration + 1
            return iteration - 1
        }

        switch stubs[index] {
        case let .deleteBranch(handler):
            return SignalProducer(value: handler(branch))
        default:
            fatalError("Stub not found")
        }
    }

    func postComment(_ comment: String, in pullRequest: PullRequest) -> SignalProducer<(), AnyError> {

        let index = iteration.modify { iteration -> Int in
            iteration = iteration + 1
            return iteration - 1
        }

        switch stubs[index] {
        case let .postComment(handler):
            return SignalProducer(value: handler(comment, pullRequest))
        default:
            fatalError("Stub not found")
        }
    }

    func removeLabel(_ label: PullRequest.Label, from pullRequest: PullRequest) -> SignalProducer<(), AnyError> {

        let index = iteration.modify { iteration -> Int in
            iteration = iteration + 1
            return iteration - 1
        }

        switch stubs[index] {
        case let .removeLabel(handler):
            return SignalProducer(value: handler(label, pullRequest))
        default:
            fatalError("Stub not found")
        }
    }
}

