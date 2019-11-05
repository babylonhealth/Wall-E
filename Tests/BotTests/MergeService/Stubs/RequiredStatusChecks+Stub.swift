@testable import Bot

extension RequiredStatusChecks {
    static func stub(
        isStrict: Bool = true,
        contexts: [String]
    ) -> RequiredStatusChecks {
        return .init(isStrict: isStrict, contexts: contexts)
    }

    static func stub(
        isStrict: Bool = true,
        indices: [Int]
    ) -> RequiredStatusChecks {
        return .stub(isStrict: isStrict, contexts: indices.map(CommitState.stubContextName))
    }
}
