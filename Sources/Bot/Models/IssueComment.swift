import Foundation

public struct IssueComment: Equatable {
    let user: GitHubUser
    let body: String
    let creationDate: Date
}

extension IssueComment: Decodable {
    private enum CodingKeys: String, CodingKey {
        case user
        case body
        case creationDate = "created_at"
    }
}
