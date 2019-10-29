@testable import Bot

extension RequiredStatusChecks {
    static func stub(
        strict: Bool = true,
        contexts: [String]
    ) -> RequiredStatusChecks {
        return .init(strict: strict, contexts: contexts)
    }

    static func stub(
        strict: Bool = true,
        indices: [Int]
    ) -> RequiredStatusChecks {
        return .stub(strict: strict, contexts: indices.map(CommitState.stubContextName))
    }
}
