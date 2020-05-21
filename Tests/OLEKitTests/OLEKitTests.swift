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

      XCTAssertEqual(error, .fileIsNotOLE(negativeURL))
    }
  }

  func testISOLEPositive() throws {
    let positiveURL = URL(fileURLWithPath: #file)
      .deletingLastPathComponent()
      .appendingPathComponent("TestWorkbook.xlsx")

    let ole = try OLEFile(positiveURL)
    XCTAssertEqual(ole.header.miniSectorSize, 64)
    XCTAssertEqual(ole.root.name, "Root Entry")
    XCTAssertEqual(ole.root.streamSize, 1920)
    XCTAssertEqual(ole.root.type, .root)
    XCTAssertEqual(ole.root.children.map { $0.name }, ["EncryptionInfo"])
    XCTAssertEqual(ole.root.children[0].streamSize, 1292)
    XCTAssertEqual(ole.root.children[0].type, .stream)
    XCTAssertEqual(
      ole.root.children[0].children.map { $0.name },
      ["\u{06}DataSpaces", "EncryptedPackage"]
    )
    XCTAssertEqual(ole.root.children[0].children[0].streamSize, 0)
    XCTAssertEqual(ole.root.children[0].children[0].type, .storage)
    XCTAssertEqual(ole.root.children[0].children[0].children.map { $0.name }, ["DataSpaceMap"])
    XCTAssertEqual(ole.root.children[0].children[1].streamSize, 8216)
    XCTAssertEqual(ole.root.children[0].children[1].type, .stream)
    XCTAssertEqual(ole.root.children[0].children[1].children.map { $0.name }, [])
    XCTAssertEqual(
      ole.root.children[0].children[0].children[0].children.map { $0.name },
      ["Version", "DataSpaceInfo"]
    )
    XCTAssertEqual(ole.root.children[0].children[0].children[0].streamSize, 112)
    XCTAssertEqual(ole.root.children[0].children[0].children[0].type, .stream)
  }
}
