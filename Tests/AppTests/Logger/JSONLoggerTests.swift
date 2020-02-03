import XCTest
@testable import App
import Logging

class JSONLoggerTests: XCTestCase {
    func test_json_logs_formatting() throws {
        let message = JSONLogger.LogMessage(
            timestamp: JSONLoggerTests.fixedDate,
            message: JSONLoggerTests.message,
            level: .debug,
            file: "somefile.swift",
            function: "somefunction",
            line: 1337,
            column: 42
        )

        let serializer = JSONEncoder()
        let data = try serializer.encode(message)

        XCTAssertEqualJSON(data, JSONLoggerTests.cannedLog)
    }

    // Check that we'd print anything above but nothing below the .info level
    func test_loglevel_compare_info_level() {
        XCTAssertEqual(LogLevel.verbose.isAtLeast(minimumLevel: .info), false)
        XCTAssertEqual(LogLevel.debug.isAtLeast(minimumLevel: .info), false)
        XCTAssertEqual(LogLevel.info.isAtLeast(minimumLevel: .info), true)
        XCTAssertEqual(LogLevel.warning.isAtLeast(minimumLevel: .info), true)
        XCTAssertEqual(LogLevel.error.isAtLeast(minimumLevel: .info), true)
        XCTAssertEqual(LogLevel.fatal.isAtLeast(minimumLevel: .info), true)
    }

    // Check that we'd print anything if minimum log level is .verbose
    func test_loglevel_compare_verbose_level() {
        XCTAssertEqual(LogLevel.verbose.isAtLeast(minimumLevel: .verbose), true)
        XCTAssertEqual(LogLevel.debug.isAtLeast(minimumLevel: .verbose), true)
        XCTAssertEqual(LogLevel.info.isAtLeast(minimumLevel: .verbose), true)
        XCTAssertEqual(LogLevel.warning.isAtLeast(minimumLevel: .verbose), true)
        XCTAssertEqual(LogLevel.error.isAtLeast(minimumLevel: .verbose), true)
        XCTAssertEqual(LogLevel.fatal.isAtLeast(minimumLevel: .verbose), true)
        XCTAssertEqual(LogLevel.custom("CUSTOM").isAtLeast(minimumLevel: .verbose), true)
    }

    // Check that custom LogLevel is equivalent to .info when comparing
    func test_loglevel_compare_custom_level() {
        let customLevel = LogLevel.custom("CUSTOM")
        XCTAssertEqual(customLevel.isAtLeast(minimumLevel: .verbose), true)
        XCTAssertEqual(customLevel.isAtLeast(minimumLevel: .debug),   true)
        XCTAssertEqual(customLevel.isAtLeast(minimumLevel: .info),    true)
        XCTAssertEqual(customLevel.isAtLeast(minimumLevel: .warning), false)
        XCTAssertEqual(customLevel.isAtLeast(minimumLevel: .error),   false)
        XCTAssertEqual(customLevel.isAtLeast(minimumLevel: .fatal),   false)
        XCTAssertEqual(customLevel.isAtLeast(minimumLevel: .custom("CUSTOM")), true)
        XCTAssertEqual(customLevel.isAtLeast(minimumLevel: .custom("OTHER")), false)
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
