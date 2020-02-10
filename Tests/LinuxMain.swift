import XCTest

import AppTests
import BotTests

var tests = [XCTestCaseEntry]()
tests += AppTests.__allTests()
tests += BotTests.__allTests()

XCTMain(tests)
