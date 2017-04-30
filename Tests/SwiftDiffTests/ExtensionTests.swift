import XCTest
@testable import SwiftDiff


class ExtensionTests: XCTestCase {

    func testSubstringTo() {
        XCTAssertEqual("", "".substring(to: 0))
        XCTAssertEqual("", "".substring(to: 1))
        XCTAssertEqual("1", "123".substring(to: 1))
        XCTAssertEqual("12", "123".substring(to: 2))
        XCTAssertEqual("123", "123".substring(to: 3))
        XCTAssertEqual("123", "123".substring(to: 4))
        XCTAssertEqual("", "123".substring(to: -1))
    }

    func testSubstringFrom() {
        XCTAssertEqual("", "".substring(from: 0))
        XCTAssertEqual("", "".substring(from: 1))
        XCTAssertEqual("23", "123".substring(from: 1))
        XCTAssertEqual("3", "123".substring(from: 2))
        XCTAssertEqual("", "123".substring(from: 3))
        XCTAssertEqual("", "123".substring(from: 4))
        XCTAssertEqual("123", "123".substring(from: -1))
    }

    func testSubstringLast() {
        XCTAssertEqual("", "".substring(last: 0))
        XCTAssertEqual("", "123".substring(last: 0))
        XCTAssertEqual("3", "123".substring(last: 1))
        XCTAssertEqual("23", "123".substring(last: 2))
        XCTAssertEqual("123", "123".substring(last: 3))
        XCTAssertEqual("123", "123".substring(last: 4))
        XCTAssertEqual("", "123".substring(last: -1))
    }
}

#if os(Linux)
    extension ExtensionTests {
        static var allTests : [(String, (ExtensionTests) -> () throws -> Void)] {
            return [
                ("testSubstringTo", testSubstringTo),
                ("testSubstringFrom", testSubstringFrom),
                ("testSubstringLast", testSubstringLast),
            ]
        }
    }
#endif
