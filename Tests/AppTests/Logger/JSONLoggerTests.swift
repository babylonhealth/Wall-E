import XCTest
@testable import App
import Bot

class JSONLoggerTests: XCTestCase {
    func test_json_logs_formatting() throws {
        let message = JSONLogger.LogMessage(
            timestamp: JSONLoggerTests.fixedDate,
            message: JSONLoggerTests.message,
            level: .debug,
            file: #file,
            function: "somefunction",
            line: 1337,
            column: 42
        )

        let serializer = JSONEncoder()
        let data = try serializer.encode(message)

        XCTAssertEqualJSON(data, JSONLoggerTests.cannedLog)
    }

    // Check that we print everything if minimum log level is .debug
    func test_loglevel_compare_debug_level() {
        XCTAssertEqual(LogLevel.debug >= .debug, true)
        XCTAssertEqual(LogLevel.info  >= .debug, true)
        XCTAssertEqual(LogLevel.error >= .debug, true)
    }

    // Check that we print anything above but nothing below the .info level
    func test_loglevel_compare_info_level() {
        XCTAssertEqual(LogLevel.debug >= .info, false)
        XCTAssertEqual(LogLevel.info  >= .info, true)
        XCTAssertEqual(LogLevel.error >= .info, true)
    }

    // Check that we print only error logs when minimum level is .error
    func test_loglevel_compare_error_level() {
        XCTAssertEqual(LogLevel.debug >= .error, false)
        XCTAssertEqual(LogLevel.info  >= .error, false)
        XCTAssertEqual(LogLevel.error >= .error, true)
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
            "context": "Tests/AppTests/Logger/JSONLoggerTests.swift:1337:42 - somefunction"
        }
        """.data(using: .utf8)!
}
