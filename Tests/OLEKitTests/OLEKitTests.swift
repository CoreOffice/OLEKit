@testable import OLEKit
import XCTest

final class OLEKitTests: XCTestCase {
  func testIsOLENegative() throws {
    let negativeURL = URL(fileURLWithPath: #file)

    switch Result(catching: { try OLEFile(negativeURL) }) {
    case .success:
      XCTFail("OLEKit did not detect that file is not ole")
    case let .failure(error):
      guard let error = error as? OLEError
      else { return XCTFail("error thrown is not OLEError") }

      XCTAssertEqual(error, .fileIsNotOLE)
    }
  }

  func testISOLEPositive() throws {
    let positiveURL = URL(fileURLWithPath: #file)
      .deletingLastPathComponent()
      .appendingPathComponent("TestWorkbook.xlsx")

    let ole = try OLEFile(positiveURL)
    XCTAssertEqual(ole.header.miniSectorSize, 64)
  }
}
