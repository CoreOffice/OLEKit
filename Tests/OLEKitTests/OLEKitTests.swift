// Copyright 2020 CoreOffice contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import OLEKit
import XCTest

final class OLEKitTests: XCTestCase {
  func testIsOLENegative() throws {
    let negativePath = URL(fileURLWithPath: #file).path

    switch Result(catching: { try OLEFile(negativePath) }) {
    case .success:
      XCTFail("OLEKit did not detect that file is not ole")
    case let .failure(error):
      guard let error = error as? OLEError
      else { return XCTFail("error thrown is not OLEError") }

      XCTAssertEqual(error, .fileIsNotOLE(negativePath))
    }
  }

  func testISOLEPositive() throws {
    let positiveURL = URL(fileURLWithPath: #file)
      .deletingLastPathComponent()
      .appendingPathComponent("TestWorkbook.xlsx")

    let ole = try OLEFile(positiveURL.path)

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

  func testDIFAT() throws {
    let targetFile = URL(fileURLWithPath: #file)
      .deletingLastPathComponent()
      .appendingPathComponent("large_strings.xls")

    if !FileManager.default.fileExists(atPath: targetFile.path) {
      let largeStrings =
        URL(string: "https://raw.githubusercontent.com/SheetJS/test_files/master/large_strings.xls")!

      let data = try Data(contentsOf: largeStrings)

      try data.write(to: targetFile)
    }

    let ole = try OLEFile(targetFile.path)
    XCTAssertEqual(ole.fat.count, 113_792)
    XCTAssertEqual(ole.root.name, "")
    XCTAssertEqual(ole.root.children.map { $0.name }, ["\u{05}SummaryInformation"])
    XCTAssertEqual(ole.root.children[0].children.map { $0.name }, [
      "Workbook",
      "\u{05}DocumentSummaryInformation",
    ])
  }
}
