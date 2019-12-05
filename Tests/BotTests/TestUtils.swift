import Foundation
import XCTest

func XCTAssertEqualJSON(_ lhs: Data, _ rhs: Data, _ message: String? =  nil, file: StaticString = #file, line: UInt = #line) {
    do {
        // We can't compare plain Data/Strings because the serialisation depends on the machines we run
        // the tests on (e.g. macOS/Linux) and order of the keys in serialised textual JSON might differ.
        // So instead we compare the NSDictionary version of those. Note that since [String: Any] is not Comparable,
        // We need to rely on JSONSerialization and NSDictionary to be able to use `==` / `XCAssertEqual`.
        let lhsObject = try JSONSerialization.jsonObject(with: lhs, options: [])
        let rhsObject = try JSONSerialization.jsonObject(with: rhs, options: [])

        if let lhsDict = lhsObject as? NSDictionary, let rhsDict = rhsObject as? NSDictionary {
            XCTAssertEqual(lhsDict, rhsDict, message ?? "", file: file, line: line)
        } else if let lhsArray = lhsObject as? NSArray, let rhsArray = rhsObject as? NSArray {
            XCTAssertEqual(lhsArray, rhsArray, message ?? "", file: file, line: line)
        } else {
            XCTFail("\(message ?? "Not Equal") - One of the objects to compare is neither an NSDictionary nor an NSArray", file: file, line: line)
        }
    } catch {
        XCTFail("Failed to deserialize JSON data to a dictionary – \(message ?? "")")
    }
}
