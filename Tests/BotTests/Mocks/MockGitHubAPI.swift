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
        case getAllStatusChecks((PullRequest) -> [PullRequest.StatusCheck])
        case mergePullRequest((PullRequest) -> Void)
        case mergeIntoBranch((PullRequest.Branch, PullRequest.Branch) -> MergeResult)
        case deleteBranch((PullRequest.Branch) -> Void)
        case postComment((String, PullRequest) -> Void)
        case removeLabel((PullRequest.Label, PullRequest) -> Void)
    }

    var stubs: Atomic<[Stubs]>
    let enforceOrder: Bool

    init(stubs: [Stubs], enforceOrder: Bool = true) {
        self.stubs = Atomic(stubs)
        self.enforceOrder = enforceOrder
    }

    func assert() -> Bool {
        return stubs.value.isEmpty
    }

    func fetchPullRequests() -> SignalProducer<[PullRequest], AnyError> {
        return nextStub { stub in
            if case let .getPullRequests(handler) = stub {
                return SignalProducer(value: handler())
            } else {
                return nil
            }
        }
    }

    func fetchPullRequest(number: UInt) -> SignalProducer<PullRequestMetadata, AnyError> {
        return nextStub { stub in
            if case let .getPullRequest(handler) = stub {
                return SignalProducer(value: handler(number))
            } else {
                return nil
            }
        }
    }

    func fetchCommitStatus(for pullRequest: PullRequest) -> SignalProducer<CommitState, AnyError> {
        return nextStub { stub in
            if case let .getCommitStatus(handler) = stub {
                return SignalProducer(value: handler(pullRequest))
            } else {
                return nil
            }
        }
    }

    func fetchRequiredStatusChecks(for branch: PullRequest.Branch) -> SignalProducer<RequiredStatusChecks, AnyError> {
        return nextStub { stub in
            if case let .getRequiredStatusChecks(handler) = stub {
                return SignalProducer(value: handler(branch))
            } else {
                return nil
            }
        }
    }

    func fetchAllStatusChecks(for pullRequest: PullRequest) -> SignalProducer<[PullRequest.StatusCheck], AnyError> {
        return nextStub { stub in
            if case let .getAllStatusChecks(handler) = stub {
                return SignalProducer(value: handler(pullRequest))
            } else {
                return nil
            }
        }
    }

    func merge(head: PullRequest.Branch, into base: PullRequest.Branch) -> SignalProducer<MergeResult, AnyError> {
        return nextStub { stub in
            if case let .mergeIntoBranch(handler) = stub {
                return SignalProducer(value: handler(base, head))
            } else {
                return nil
            }
        }
    }

    func mergePullRequest(_ pullRequest: PullRequest) -> SignalProducer<(), AnyError> {
        return nextStub { stub in
            if case let .mergePullRequest(handler) = stub {
                return SignalProducer(value: handler(pullRequest))
            } else {
                return nil
            }
        }
    }

    func deleteBranch(named branch: PullRequest.Branch) -> SignalProducer<(), AnyError> {
        return nextStub { stub in
            if case let .deleteBranch(handler) = stub {
                return SignalProducer(value: handler(branch))
            } else {
                return nil
            }
        }
    }

    func postComment(_ comment: String, in pullRequest: PullRequest) -> SignalProducer<(), AnyError> {
        return nextStub { stub in
            if case let .postComment(handler) = stub {
                return SignalProducer(value: handler(comment, pullRequest))
            } else {
                return nil
            }
        }
    }

    func removeLabel(_ label: PullRequest.Label, from pullRequest: PullRequest) -> SignalProducer<(), AnyError> {
        return nextStub { stub in
            if case let .removeLabel(handler) = stub {
                return SignalProducer(value: handler(label, pullRequest))
            } else {
                return nil
            }
        }
    }

    private func nextStub<T>(matching: (Stubs) -> T?) -> T {
        return stubs.modify { stubs -> T in
            for idx in stubs.indices {
                if let t = matching(stubs[idx]) {
                    stubs.remove(at: idx)
                    return t
                } else if enforceOrder {
                    break
                }
            }
            fatalError("Stub not found")
        }
    }
}

