import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
  [
    testCase(OLEKitTests.allTests),
  ]
}
#endif
