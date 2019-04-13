import XCTest

extension GitHubDecodingTests {
    static let __allTests = [
        ("test_parsing_pull_request_event_context", test_parsing_pull_request_event_context),
    ]
}

extension GitHubEventsTests {
    static let __allTests = [
        ("test_handling_ping_event", test_handling_ping_event),
        ("test_handling_pull_request_event", test_handling_pull_request_event),
        ("test_handling_unknown_event", test_handling_unknown_event),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(GitHubDecodingTests.__allTests),
        testCase(GitHubEventsTests.__allTests),
    ]
}
#endif
