import XCTest
@testable import App

class LogsTests: XCTestCase {
    func test_logzio_json_formatting() throws {
        let message = LogzIOLogger.LogMessage(
            timestamp: LogsTests.fixedDate,
            message: LogsTests.message,
            level: .debug,
            file: "somefile.swift",
            function: "somefunction",
            line: 1337,
            column: 42
        )

        let serializer = JSONEncoder()
        let data = try serializer.encode(message)

        print(message)
        XCTAssertEqualJSON(data, LogsTests.cannedLog)
    }

    // MARK: Canned data

    private static let fixedDate: Date = {
        return DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2020, month: 2, day: 1,
            hour: 10, minute: 20, second: 30,
            nanosecond: 456_000_000
        ).date!
    }()

    private static let message = """
        Some long log message

        For example, one spanning multiple lines
        like an HTTP request body for example
        """

    private static let escapedMessage = message
        .split(separator: "\n", omittingEmptySubsequences: false)
        .joined(separator: "\\n")

    private static let cannedLog = """
        {
            "@timestamp": "2020-02-01T10:20:30.456+0000",
            "message": "\(escapedMessage)",
            "level": "DEBUG",
            "context": "somefile.swift:1337:42 - somefunction"
        }
        """.data(using: .utf8)!
}
