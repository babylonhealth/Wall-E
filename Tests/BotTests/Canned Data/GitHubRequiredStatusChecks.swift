let GitHubRequiredStatusChecks: String = """
{
    "url": "https://api.github.com/repos/babylonhealth/babylon-ios/branches/develop/protection/required_status_checks",
    "strict": true,
    "contexts": [
        "ci/circleci: Build: SDK",
        "ci/circleci: UnitTests: Ascension",
        "ci/circleci: UnitTests: BabylonKSA",
        "ci/circleci: UnitTests: BabylonUS",
        "ci/circleci: UnitTests: Telus",
        "ci/circleci: SnapshotTests: BabylonChatBotUI",
        "ci/circleci: SnapshotTests: BabylonUI",
        "ci/circleci: SnapshotTests: Babylon"
    ],
    "contexts_url": "https://api.github.com/repos/babylonhealth/babylon-ios/branches/develop/protection/required_status_checks/contexts"
}
"""
