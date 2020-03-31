import Foundation

public struct IssueComment: Equatable {
    let user: GitHubUser
    let body: String
    let creationDate: Date
}

extension IssueComment: Decodable {
    private static let dateFormatter: DateFormatter = {
        // 2020-03-30T11:26:18
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return df
    }()

    private enum CodingKeys: String, CodingKey {
        case user
        case body
        case created_at
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.user = try container.decode(GitHubUser.self, forKey: .user)
        self.body = try container.decode(String.self, forKey: .body)
        let dateString = try container.decode(String.self, forKey: .created_at)
        guard let date = Self.dateFormatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(forKey: .created_at, in: container, debugDescription: "Invalid date format")
        }
        self.creationDate = date
    }
}
