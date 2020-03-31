let GitHubIssueComment = #"""
{
  "url": "https://api.github.com/repos/babylonhealth/Wall-E/pulls/comments/400979441",
  "pull_request_review_id": 384816651,
  "id": 400979441,
  "node_id": "MDI0OlB1bGxSZXF1ZXN0UmV2aWV3Q29tbWVudDQwMDk3OTQ0MQ==",
  "diff_hunk": "@@ -0,0 +1,34 @@\n+import Foundation\n+\n+public struct IssueComment: Equatable {\n+    let user: GitHubUser\n+    let body: String\n+    let creationDate: Date\n+}\n+\n+extension IssueComment: Decodable {\n+    private static let dateFormatter: DateFormatter = {\n+        // 2020-03-30T11:26:18\n+        let df = DateFormatter()\n+        df.locale = Locale(identifier: \"en_US_POSIX\")\n+        df.dateFormat = \"yyyy-MM-dd'T'HH:mm:ssZ\"\n+        return df\n+    }()\n+\n+    private enum CodingKeys: String, CodingKey {\n+        case user\n+        case body\n+        case created_at\n+    }\n+\n+    public init(from decoder: Decoder) throws {\n+        let container = try decoder.container(keyedBy: CodingKeys.self)\n+        self.user = try container.decode(GitHubUser.self, forKey: .user)\n+        self.body = try container.decode(String.self, forKey: .body)\n+        let dateString = try container.decode(String.self, forKey: .created_at)\n+        guard let date = Self.dateFormatter.date(from: dateString) else {",
  "path": "Sources/Bot/Models/IssueComment.swift",
  "position": 29,
  "original_position": 29,
  "commit_id": "8b6a72d20ab8f5cb6cd6d6bf9300bb14fdb9e681",
  "original_commit_id": "8b6a72d20ab8f5cb6cd6d6bf9300bb14fdb9e681",
  "user": {
    "login": "AliSoftware",
    "id": 216089,
    "node_id": "MDQ6VXNlcjIxNjA4OQ==",
    "avatar_url": "https://avatars2.githubusercontent.com/u/216089?v=4",
    "gravatar_id": "",
    "url": "https://api.github.com/users/AliSoftware",
    "html_url": "https://github.com/AliSoftware",
    "followers_url": "https://api.github.com/users/AliSoftware/followers",
    "following_url": "https://api.github.com/users/AliSoftware/following{/other_user}",
    "gists_url": "https://api.github.com/users/AliSoftware/gists{/gist_id}",
    "starred_url": "https://api.github.com/users/AliSoftware/starred{/owner}{/repo}",
    "subscriptions_url": "https://api.github.com/users/AliSoftware/subscriptions",
    "organizations_url": "https://api.github.com/users/AliSoftware/orgs",
    "repos_url": "https://api.github.com/users/AliSoftware/repos",
    "events_url": "https://api.github.com/users/AliSoftware/events{/privacy}",
    "received_events_url": "https://api.github.com/users/AliSoftware/received_events",
    "type": "User",
    "site_admin": false
  },
  "body": "Oh forgot about that one, good point.\r\nAnd just saw that there's actually already code for that in `Decoding.swift` so all that shouldn't even be needed at all indeed. ",
  "created_at": "2020-03-31T14:54:28Z",
  "updated_at": "2020-03-31T14:54:28Z",
  "html_url": "https://github.com/babylonhealth/Wall-E/pull/57#discussion_r400979441",
  "pull_request_url": "https://api.github.com/repos/babylonhealth/Wall-E/pulls/57",
  "author_association": "CONTRIBUTOR",
  "_links": {
    "self": {
      "href": "https://api.github.com/repos/babylonhealth/Wall-E/pulls/comments/400979441"
    },
    "html": {
      "href": "https://github.com/babylonhealth/Wall-E/pull/57#discussion_r400979441"
    },
    "pull_request": {
      "href": "https://api.github.com/repos/babylonhealth/Wall-E/pulls/57"
    }
  },
  "in_reply_to_id": 400977181
}
"""#
