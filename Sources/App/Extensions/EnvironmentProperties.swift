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

    static func requiresAllGitHubStatusChecks() throws -> Bool {
        guard let stringValue: String = Environment.get("REQUIRES_ALL_STATUS_CHECKS") else {
            return false // defaults to only consider required checks
        }
        return ["yes", "1", "true"].contains(stringValue.lowercased())
    }

    static func statusChecksTimeout() throws -> TimeInterval? {
        let value: String = try Environment.get("STATUS_CHECKS_TIMEOUT")
        return TimeInterval(value)
    }

    /// Delay to wait after a MergeService is back in idle state before destroying it
    static func idleMergeServiceCleanupDelay() throws -> TimeInterval? {
        let value: String? = Environment.get("IDLE_BRANCH_QUEUE_CLEANUP_DELAY")
        return value.flatMap(TimeInterval.init)
    }

    static func mergeLabel() throws -> PullRequest.Label {
        return PullRequest.Label(name: try Environment.get("MERGE_LABEL"))
    }

    static func topPriorityLabels() throws -> [PullRequest.Label] {
        let labelsList: String = try Environment.get("TOP_PRIORITY_LABELS")
        return labelsList.split(separator: ",").map { name in
            PullRequest.Label(name: String(name))
        }
    }

    static func get(_ key: String) throws -> String {
        guard let value = Environment.get(key) as String?
            else { throw ConfigurationError.missingConfiguration(message: "💥 key `\(key)` not found in environment") }

        return value
    }
}
