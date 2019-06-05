import Foundation

public struct PullRequest: Equatable {
    public let number: UInt
    public let title: String
    public let author: Author
    public let source: Branch
    public let target: Branch
    public let labels: [Label]
}

extension PullRequest {
    public struct Author: Equatable, Decodable {
        public let login: String
    }
}

extension PullRequest {
    public struct Label: Equatable, Decodable {
        public let name: String
    }
}

extension PullRequest {
    public struct Branch: Equatable, Decodable {
        public let ref: String
        public let sha: String
    }
}

extension PullRequest {
    public enum Action: String, Decodable {
        case assigned
        case unassigned
        case reviewRequested = "review_requested"
        case reviewRequestRemoved = "review_request_removed"
        case labeled
        case unlabeled
        case opened
        case edited
        case closed
        case reopened
        case synchronize
    }
}

extension PullRequest: Decodable {
    enum CodingKeys: String, CodingKey {
        case number
        case title
        case author = "user"
        case source = "head"
        case target = "base"
        case labels
    }
}
