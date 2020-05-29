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

@testable import OLEKit
import XCTest

final class DataWriterTests: XCTestCase {
  func testLittleEndian() {
    let writer = DataWriter()

    writer.write(UInt32.max)

    let reader = DataReader(writer.data)
    let uint32: UInt32 = reader.read()

    XCTAssertEqual(uint32, UInt32.max)
  }
}
