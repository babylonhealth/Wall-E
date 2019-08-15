import Foundation

public struct StatusEvent: Equatable, Decodable {
    let sha: String
    let context: String
    let description: String?
    let state: State
    let branches: [Branch]

    func isRelative(toBranch branchName: String) -> Bool {
        return branches.contains { branch in branch.name == branchName }
    }

    public enum State: String, Decodable {
        case pending
        case success
        case failure
        case error
    }

    public struct Branch: Equatable, Decodable {
        let name: String
    }
}

extension StatusEvent: CustomDebugStringConvertible {
    public var debugDescription: String {
         return "StatusEvent(sha: \(sha), context: \"\(context)\", state: \(state), branches: \(branches))"
    }
}

extension StatusEvent.State: CustomDebugStringConvertible {
    public var debugDescription: String {
        return rawValue
    }
}

extension StatusEvent.Branch: CustomDebugStringConvertible {
    public var debugDescription: String {
        return  name
    }
}
