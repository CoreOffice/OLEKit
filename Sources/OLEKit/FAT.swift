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

/// Constants for Sector IDs (from AAF specifications)
enum SectorID: UInt32 {
  /// (-6) maximum SECT
  case maximumSector = 0xFFFF_FFFA

  /// (-4) denotes a DIFAT sector in a FAT
  case difatSector = 0xFFFF_FFFC

  /// (-3) denotes a FAT sector in a FAT
  case fatSector = 0xFFFF_FFFD

  ///  (-2) end of a virtual stream chain
  case endOfChain = 0xFFFF_FFFE

  ///  (-1) unallocated sector
  case freeSector = 0xFFFF_FFFF
}

/** The 1st sector of the file contains sector numbers for the first 109
 FAT sectors, right after the header which is 76 bytes long.
 (always 109, whatever the sector size: 512 bytes = 76+4*109)
 Additional sectors are described by DIFAT blocks */
private let maxFATSectorsCount: UInt32 = 109

extension FileHandle {
  func loadSector(_ header: Header, index: UInt32) throws -> DataReader {
    let sectorOffset = UInt64(header.sectorSize) * UInt64(index + 1)

    guard sectorOffset < header.fileSize
    else { throw OLEError.invalidFATSector(byteOffset: sectorOffset) }

    seek(toFileOffset: sectorOffset)
    return DataReader(readData(ofLength: Int(header.sectorSize)))
  }

  func loadSectors(
    _ header: Header,
    indexStream: inout DataReader,
    count: UInt32
  ) throws -> [UInt32] {
    var result = [UInt32]()
    result.reserveCapacity(Int(count))

    for _ in 0..<count {
      let currentIndex: UInt32 = indexStream.read()

      guard currentIndex != SectorID.endOfChain.rawValue &&
        currentIndex != SectorID.freeSector.rawValue
      else { break }

      let sectorStream = try loadSector(header, index: currentIndex)
      for _ in 0..<(header.sectorSize / 4) {
        result.append(sectorStream.read())
      }
    }

    return result
  }

  func loadFAT(headerStream: inout DataReader, _ header: Header) throws -> [UInt32] {
    var fat = [UInt32]()

    try fat.append(contentsOf: loadSectors(
      header,
      indexStream: &headerStream,
      count: maxFATSectorsCount
    ))

    // Since FAT is read from fixed-size sectors, it may contain more values
    // than the actual number of sectors in the file.
    // Keep only the relevant sector indexes:
    if UInt64(fat.count) > header.sectorsCount {
      fat = Array(fat.prefix(header.sectorsCount))
    }

    if header.diFATSectorsCount > 0 {
      // There's a DIFAT because file is larger than 6.8MB.
      // Some checks just in case:

      // There must be at least 109 blocks in header and the rest in
      // DIFAT, so number of sectors must be >109.
      guard header.fatSectorsCount > maxFATSectorsCount else {
        throw OLEError.incorrectNumberOfFATSectors(
          actual: header.fatSectorsCount,
          expected: maxFATSectorsCount
        )
      }

      guard header.firstDIFATSector < UInt(header.sectorsCount) else {
        throw OLEError.sectorIndexInDIFATOOB(
          actual: header.firstDIFATSector,
          expected: header.sectorsCount
        )
      }

      // We compute the necessary number of DIFAT sectors :
      // Number of pointers per DIFAT sector = (sectorsize/4)-1
      // (-1 because the last pointer is the next DIFAT sector number)
      let sectorPointersCount = UInt32(header.sectorSize / 4) - 1
      // (if 512 bytes: each DIFAT sector = 127 pointers + 1 towards next DIFAT sector)
      let inferredCount =
        (header.fatSectorsCount - 109 + sectorPointersCount - 1) / sectorPointersCount

      guard header.diFATSectorsCount == inferredCount else {
        throw OLEError.incorrectNumberOFDIFATSectors(
          actual: header.diFATSectorsCount,
          expected: inferredCount
        )
      }

      var currentSectorID = header.firstDIFATSector
      for _ in 0..<inferredCount {
        var difatSectorStream = try loadSector(header, index: currentSectorID)
        try fat.append(contentsOf: loadSectors(
          header,
          indexStream: &difatSectorStream,
          count: sectorPointersCount
        ))
        // last DIFAT pointer is next DIFAT sector
        currentSectorID = difatSectorStream.read()
      }
    }

    return fat
  }

  func loadMiniFAT(_ header: Header, root: DirectoryEntry, fat: [UInt32]) throws -> [UInt32] {
    // MiniFAT is stored in a standard  sub-stream, pointed to by a header
    // field.
    // NOTE: there are two sizes to take into account for this stream:
    // 1) Stream size is calculated according to the number of sectors
    //    declared in the OLE header. This allocated stream may be more than
    //    needed to store the actual sector indexes.
    //  2) Actually used size is calculated by dividing the MiniStream size
    //    (given by root entry size) by the size of mini sectors, *4 for
    //    32 bits indexes:

    let streamSize = UInt64(header.miniFATSectorsCount) * UInt64(header.sectorSize)
    let miniSectorsCount = (root.streamSize + UInt64(header.miniSectorSize) - 1) /
      UInt64(header.miniSectorSize)

    let stream = try oleStream(
      sectorID: header.firstMiniFATSector,
      expectedStreamSize: streamSize,
      firstSectorOffset: UInt64(header.sectorSize),
      sectorSize: header.sectorSize,
      fat: fat
    )

    var result = [UInt32]()
    result.reserveCapacity(Int(miniSectorsCount))
    for _ in 0..<miniSectorsCount {
      result.append(stream.read())
    }

    return result
  }
}
