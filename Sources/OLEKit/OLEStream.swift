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

import Foundation

extension DataStream {
  init(
    _ fileHandle: FileHandle,
    sectorID: UInt32,
    expectedStreamSize: Int? = nil,
    firstSectorOffset: UInt64,
    sectorSize: UInt16,
    fat: [UInt32]
  ) throws {
    guard !(expectedStreamSize == 0 && sectorID == SectorID.endOfChain.rawValue)
    else { throw OLEError.invalidEmptyStream }

    let sectorSize = Int(sectorSize)
    let calculatedStreamSize = expectedStreamSize ?? fat.count * Int(sectorSize)
    let numberOfSectors = (calculatedStreamSize + sectorSize - 1) / sectorSize

    // This number should (at least) be less than the total number of
    // sectors in the given FAT:
    guard numberOfSectors <= fat.count
    else { throw OLEError.streamTooLarge(actual: numberOfSectors, expected: fat.count) }

    var currentSectorID = sectorID
    var data = Data()
    for _ in 0..<numberOfSectors {
      guard currentSectorID != SectorID.endOfChain.rawValue else {
        if expectedStreamSize != nil {
          // This means that the stream is smaller than declared:
          throw OLEError.incompleteStream(
            firstSectorID: sectorID,
            actual: data.count,
            expected: numberOfSectors * sectorSize
          )
        } else {
          // Reached end of chain for a stream with unknown size
          break
        }
      }

      guard currentSectorID >= 0 && UInt64(currentSectorID) < fat.count
      else { throw OLEError.invalidOLEStreamSectorID(id: currentSectorID, total: fat.count) }

      fileHandle.seek(
        toFileOffset: firstSectorOffset + UInt64(sectorSize) * UInt64(currentSectorID)
      )

      // if sector is the last of the file, sometimes it is not a
      // complete sector (of 512 or 4K), so we may read less than
      // sectorsize.
      if sectorID == fat.count - 1 {
        data.append(fileHandle.readDataToEndOfFile())
      } else {
        data.append(fileHandle.readData(ofLength: Int(sectorSize)))
      }

      currentSectorID = fat[Int(currentSectorID)]
    }

    if data.count > calculatedStreamSize {
      // `data` is truncated to the expected stream size
      data = data.prefix(calculatedStreamSize)
    } else if let expectedStreamSize = expectedStreamSize, data.count < expectedStreamSize {
      // the stream size was not inferred, but was smaller than expected
      throw OLEError.incompleteStream(
        firstSectorID: sectorID,
        actual: data.count,
        expected: expectedStreamSize
      )
    }

    self.data = data
  }
}
