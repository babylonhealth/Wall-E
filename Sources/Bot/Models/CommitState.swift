import Foundation

public struct CommitState: Decodable, Equatable {

    public enum State: String, Decodable {
        case pending
        case failure
        case success
    }

    public struct Status: Equatable, Decodable {
        public let state: State
        public let description: String
        public let context: String
    }

    /// Combined state for _all_ the checks
    /// - `.failure` if any of the status checks (`statuses.map(\.state)`) reports an error or `.failure`
    /// - `.pending` if there are no statuses, or a status check is `.pending`
    /// - `.success` if the latest status for all checks is `.success`
    /// See https://developer.github.com/v3/repos/statuses/#get-the-combined-status-for-a-specific-ref
    public let state: State

    /// Individual status of each check
    public let statuses: [Status]
}


extension CommitState.State {

    /// Compute the combined state for a set of states.
    /// This logic replicates the behavior provided by the GitHub API (see `CommitState.state` property provided by GitHub API above)
    ///
    /// We use this method ourselves to:
    ///  - compute a similar combined state as GitHub API provides, but for only a subset of checks (especially only considering _required_ checks)
    ///  - create stubs for `CommitState` in the tests to replicate the GitHub API behavior
    /// - Parameter states: List of states to compute the combined state for
    /// - Returns
    ///   - `.failure` if any of the status checks reports a `.failure`
    ///   - `.pending` if there are no statuses, or a status check is `.pending`
    ///   - `.success` if the latest status for all checks is `.success`
    static func combinedState(for states: [CommitState.State]) -> CommitState.State {
        if states.contains(.failure) {
            return .failure
        } else if states.contains(.pending) {
            return .pending
        } else {
            return .success
        }
    }
}
