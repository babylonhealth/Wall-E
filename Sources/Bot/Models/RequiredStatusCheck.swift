import Foundation

public struct RequiredStatusChecks: Decodable, Equatable {
    public let strict: Bool // Require branches to be up to date before merging?
    public let contexts: [String] // Names of status checks marked as Required
}
