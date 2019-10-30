@testable import Bot

extension CommitState {
    static func stub(states: [CommitState.State]) -> CommitState {
        guard !states.isEmpty else {
            return CommitState(state: .pending, statuses: [])
        }

        return .init(
            state: CommitState.State.combinedState(for: states),
            statuses: states.enumerated().map { item in
                CommitState.Status.stub(state: item.element, context: CommitState.stubContextName(item.offset))
            }
        )
    }

    static func stubContextName(_ index: Int) -> String {
        return "Check #\(index+1)"
    }
}

extension CommitState.Status {
    static func stub(state: CommitState.State, context: String) -> CommitState.Status {
        return .init(state: state, description: "\(context) is \(state)", context: context)
    }
}
