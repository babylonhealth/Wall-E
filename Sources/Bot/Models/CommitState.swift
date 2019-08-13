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

    public let state: State
    public let statuses: [Status]
}
