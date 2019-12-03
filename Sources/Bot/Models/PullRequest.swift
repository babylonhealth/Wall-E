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
    public struct Author: Equatable, Codable {
        public let login: String
    }
}

extension PullRequest {
    public struct Label: Equatable, Codable {
        public let name: String

        public init(name: String) {
            self.name = name
        }
    }
}

extension PullRequest {
    public struct Branch: Equatable, Codable {
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

extension PullRequest: Codable {
    enum CodingKeys: String, CodingKey {
        case number
        case title
        case author = "user"
        case source = "head"
        case target = "base"
        case labels
    }
}

extension PullRequest: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "PR(#\(number), base: \(target), head: \"\(source)\")"
    }
}

extension PullRequest.Branch: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "Branch(\(ref), \(sha))"
    }
}

extension PullRequest {
    func isLabelled(with label: PullRequest.Label) -> Bool {
        return labels.contains(label)
    }
    func isLabelled(withOneOf possibleLabels: [PullRequest.Label]) -> Bool {
        return labels.contains(where: possibleLabels.contains)
    }
}
