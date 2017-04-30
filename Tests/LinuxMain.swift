import XCTest
@testable import SwiftDiffTests

XCTMain([
     testCase(SwiftDiffTests.allTests),
     testCase(ExtensionTests.allTests),
])
