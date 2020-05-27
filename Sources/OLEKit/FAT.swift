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
  func loadSector(_ header: Header, index: UInt32) throws -> DataStream {
    let sectorOffset = UInt64(header.sectorSize) * UInt64(index + 1)

    guard sectorOffset < header.fileSize
    else { throw OLEError.invalidFATSector(byteOffset: sectorOffset) }

    seek(toFileOffset: sectorOffset)
    return DataStream(readData(ofLength: Int(header.sectorSize)))
  }

  func loadSectors(
    _ header: Header,
    indexStream: inout DataStream,
    count: UInt32
  ) throws -> [UInt32] {
    var result = [UInt32]()

    for _ in 0..<count {
      let currentIndex: UInt32 = indexStream.read()

      guard currentIndex != SectorID.endOfChain.rawValue &&
        currentIndex != SectorID.freeSector.rawValue
      else { break }

      var sectorStream = try loadSector(header, index: currentIndex)
      for _ in 0..<(header.sectorSize / 4) {
        result.append(sectorStream.read())
      }
    }

    return result
  }

  func loadFAT(headerStream: inout DataStream, _ header: Header) throws -> [UInt32] {
    var fat = [UInt32]()

    try fat.append(contentsOf: loadSectors(
      header,
      indexStream: &headerStream,
      count: maxFATSectorsCount
    ))

    // Since FAT is read from fixed-size sectors, it may contain more values
    // than the actual number of sectors in the file.
    // Keep only the relevant sector indexes:
    if UInt64(fat.count) > header.sectorCount {
      fat = Array(fat.prefix(header.sectorCount))
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

      guard header.firstDIFATSector < UInt(header.sectorCount) else {
        throw OLEError.sectorIndexInDIFATOOB(
          actual: header.firstDIFATSector,
          expected: header.sectorCount
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
}
