import Vapor
import Bot

extension Environment {

    static func gitHubWebhookSecret() throws -> String {
        return try Environment.get("GITHUB_WEBHOOK_SECRET")
    }

    static func gitHubToken() throws -> String {
        return try Environment.get("GITHUB_TOKEN")
    }

    static func gitHubOrganization() throws -> String {
        return try Environment.get("GITHUB_ORGANIZATION")
    }

    static func gitHubRepository() throws -> String {
        return try Environment.get("GITHUB_REPOSITORY")
    }

    static func mergeLabel() throws -> PullRequest.Label {
        return PullRequest.Label(name: try Environment.get("MERGE_LABEL"))
    }

    static func get(_ key: String) throws -> String {
        guard let value = Environment.get(key) as String?
            else { throw ConfigurationError.missingConfiguration(message: "💥 key `\(key)` not found in environment") }

        return value
    }
}
