@testable import OLEKit
import XCTest

final class OLEKitTests: XCTestCase {
  func testIsOLE() throws {
    let negativeURL = URL(fileURLWithPath: #file)

    let negativeFH = try FileHandle(forReadingFrom: negativeURL)

    XCTAssertFalse(try negativeFH.isOLE())

    let positiveURL = URL(fileURLWithPath: #file)
      .deletingLastPathComponent()
      .appendingPathComponent("TestWorkbook.xlsx")

    let ole = try OLEFile(positiveURL)
    XCTAssertEqual(ole.miniSectorSize, 64)
  }
}
