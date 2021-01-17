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

private let workbookMiniFAT: [UInt32] = [
  1, 4_294_967_294, 3, 4_294_967_294, 4_294_967_294, 6, 7, 8, 4_294_967_294, 10,
  11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 4_294_967_294,
]

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

    XCTAssertEqual(ole.miniFAT, workbookMiniFAT)
    XCTAssertEqual(ole.header.miniSectorSize, 64)
    XCTAssertEqual(ole.root.name, "Root Entry")
    XCTAssertEqual(ole.root.streamSize, 1920)
    XCTAssertEqual(ole.root.type, .root)
    XCTAssertEqual(
      ole.root.children.map { $0.name },
      ["\u{06}DataSpaces", "EncryptedPackage", "EncryptionInfo"]
    )
    XCTAssertEqual(ole.root.children[2].streamSize, 1292)
    XCTAssertEqual(ole.root.children[2].type, .stream)
    XCTAssertEqual(
      ole.root.children[0].children.map { $0.name },
      ["Version", "TransformInfo", "DataSpaceInfo", "DataSpaceMap"]
    )
    XCTAssertEqual(ole.root.children[0].children[0].streamSize, 76)
    XCTAssertEqual(ole.root.children[0].children[0].type, .stream)
    XCTAssertEqual(ole.root.children[0].children[0].children.map { $0.name }, [])
    XCTAssertEqual(ole.root.children[0].children[1].streamSize, 0)
    XCTAssertEqual(ole.root.children[0].children[1].type, .storage)
    XCTAssertEqual(
      ole.root.children[0].children[1].children.map { $0.name },
      ["StrongEncryptionTransform"]
    )

    let stream = try ole.stream(ole.root.children[2])
    XCTAssertEqual(UInt64(stream.data.count), 1292)
    let major: UInt16 = stream.read()
    let minor: UInt16 = stream.read()
    XCTAssertEqual([major, minor], [4, 4])
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
    XCTAssertEqual(ole.root.children.map { $0.name }, [
      "\u{01}CompObj",
      "Workbook",
      "\u{05}DocumentSummaryInformation",
      "\u{05}SummaryInformation",
    ])
    XCTAssertEqual(ole.root.children[0].children.map { $0.name }, [])
    XCTAssertEqual(ole.root.children[1].children.map { $0.name }, [])
    XCTAssertEqual(ole.root.children[2].children.map { $0.name }, [])
    XCTAssertEqual(ole.root.children[3].children.map { $0.name }, [])
  }

  func testHWP() throws {
    let url = URL(fileURLWithPath: #file)
      .deletingLastPathComponent()
      .appendingPathComponent("blank.hwp")
    let ole = try OLEFile(url.path)
    let fileHeaderStream = ole.root.children.first(where: { $0.name == "FileHeader" })!
    let reader = try ole.stream(fileHeaderStream)
    let data = reader.readData(ofLength: 32)
    let signature = String(data: data, encoding: .ascii)
    XCTAssertEqual(signature, "HWP Document File\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0")
    XCTAssertEqual(ole.root.children.map { $0.name }, [
      "BinData",
      "Scripts",
      "PrvText",
      "DocInfo",
      "DocOptions",
      "PrvImage",
      "BodyText",
      "\u{05}HwpSummaryInformation",
      "FileHeader",
    ])
  }

  #if os(iOS) || os(watchOS) || os(tvOS) || os(macOS)

  func testOLEFile2() throws {
    let url = URL(fileURLWithPath: #file)
      .deletingLastPathComponent()
      .appendingPathComponent("blank.hwp")
    let wrapper = try FileWrapper(url: url, options: .immediate)
    let ole = try OLEFile(url.path)
    let ole2 = try OLEFile2(wrapper)
    XCTAssertEqual(ole.header, ole2.header)
    XCTAssertEqual(ole.fat, ole2.fat)
    XCTAssertEqual(ole.miniFAT, ole2.miniFAT)
    XCTAssertEqual(ole.root, ole2.root)
  }

  #endif
}
