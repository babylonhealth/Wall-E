import Foundation

public struct RequiredStatusChecks: Decodable, Equatable {
    /// Require branches to be up to date before merging?
    public let strict: Bool
    /// Names of status checks marked as Required
    public let contexts: [String]
}
