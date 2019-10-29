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

    /// Combined state for all the checks
    /// - `.failure` if any of the contexts report as error or failure
    /// - `.pending` if there are no statuses or a context is pending
    /// - `.success` if the latest status for all contexts is success
    public let state: State

    /// Individual status of each check
    public let statuses: [Status]
}
