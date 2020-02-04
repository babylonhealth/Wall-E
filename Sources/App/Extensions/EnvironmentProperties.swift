import Vapor
import Bot

extension Environment {

    /// GitHub Webhook secret
    static func gitHubWebhookSecret() throws -> String {
        return try Environment.get("GITHUB_WEBHOOK_SECRET")
    }

    /// GitHub Token
    static func gitHubToken() throws -> String {
        return try Environment.get("GITHUB_TOKEN")
    }

    /// GitHub Organisation name (`<orgname>` part of `github.com/<orgname>/<repo>` url)
    static func gitHubOrganization() throws -> String {
        return try Environment.get("GITHUB_ORGANIZATION")
    }

    /// name of GitHub Repository to run the MergeBot on (`<repo>` part of `github.com/<orgname>/<repo>` url)
    static func gitHubRepository() throws -> String {
        return try Environment.get("GITHUB_REPOSITORY")
    }

    /// If set to YES/1/TRUE, the Merge Bot will require all GitHub status checks to pass before accepting to merge
    /// Otherwise, only the GitHub status checks that are marked as "required" in the GitHub settings to pass
    static func requiresAllGitHubStatusChecks() throws -> Bool {
        guard let stringValue: String = Environment.get("REQUIRES_ALL_STATUS_CHECKS") else {
            return false // defaults to only consider required checks
        }
        return ["yes", "1", "true"].contains(stringValue.lowercased())
    }

    /// Maximum time (in seconds) to wait for a status check to finish running and report a red/green status
    /// Defaults to 5400 (90 minutes)
    static func statusChecksTimeout() -> TimeInterval? {
        let value: String? = Environment.get("STATUS_CHECKS_TIMEOUT")
        return value.flatMap(TimeInterval.init)
    }

    /// Delay (in seconds) to wait after a MergeService is back in idle state before killing it.
    /// Defaults to 300 seconds (5 minutes)
    static func idleMergeServiceCleanupDelay() -> TimeInterval? {
        let value: String? = Environment.get("IDLE_BRANCH_QUEUE_CLEANUP_DELAY")
        return value.flatMap(TimeInterval.init)
    }

    /// The text of the GitHub label that you want to use to trigger the MergeBot and add a PR to the queue
    static func mergeLabel() throws -> PullRequest.Label {
        return PullRequest.Label(name: try Environment.get("MERGE_LABEL"))
    }

    /// Comma-separated list of GitHub label names that you want to use to bump a PR's priority – and make it jump to the front of the queue
    static func topPriorityLabels() throws -> [PullRequest.Label] {
        let labelsList: String = try Environment.get("TOP_PRIORITY_LABELS")
        return labelsList.split(separator: ",").map { name in
            PullRequest.Label(name: String(name))
        }
    }

    /// Name of the minimum log level to start logging. Defaults to "INFO" level
    ///
    /// Valid values are, in decreasing order of verbosity:
    ///  - `DEBUG`
    ///  - `INFO`
    ///  - `ERROR`
    ///
    /// Any log that is higher that the `minimumLogLevel` in this list will be filtered out.
    /// e.g. a `minimumLogLevel` of `INFO` will filter out `DEBUG` logs and will only print `INFO` and `ERROR` logs
    static func minimumLogLevel() -> Bot.LogLevel {
        let value: String? = Environment.get("MINIMUM_LOG_LEVEL")
        return value
            .map { $0.uppercased() }
            .flatMap(Bot.LogLevel.init(rawValue:)) ?? .info
    }

    static func get(_ key: String) throws -> String {
        guard let value = Environment.get(key) as String?
            else { throw ConfigurationError.missingConfiguration(message: "💥 key `\(key)` not found in environment") }

        return value
    }
}
