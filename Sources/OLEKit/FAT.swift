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
private let maxNumberOfFATSectors = 109

extension FileHandle {
  func loadFAT(headerStream: inout DataStream, _ header: Header) throws -> [UInt32] {
    var fat = [UInt32]()
    for _ in 0..<maxNumberOfFATSectors {
      let sectorIndex: UInt32 = headerStream.read()

      guard sectorIndex != SectorID.endOfChain.rawValue &&
        sectorIndex != SectorID.freeSector.rawValue
      else { break }

      let sectorOffset = UInt64(header.sectorSize) * UInt64(sectorIndex + 1)

      guard sectorOffset < header.fileSize
      else { throw OLEError.invalidFATSector(byteOffset: sectorOffset) }

      seek(toFileOffset: sectorOffset)
      var sectorStream = DataStream(readData(ofLength: Int(header.sectorSize)))
      for _ in 0..<(header.sectorSize / 4) {
        fat.append(sectorStream.read())
      }
    }

    // Since FAT is read from fixed-size sectors, it may contain more values
    // than the actual number of sectors in the file.
    // Keep only the relevant sector indexes:
    if UInt64(fat.count) > header.numberOfSectors {
      fat = Array(fat.prefix(header.numberOfSectors))
    }

    if header.numDIFATSectors > 0 {
      // There's a DIFAT because file is larger than 6.8MB.
      // Some checks just in case:

      // There must be at least 109 blocks in header and the rest in
      // DIFAT, so number of sectors must be >109.
      guard header.numFATSectors > maxNumberOfFATSectors else {
        throw OLEError.incorrectNumberOfFATSectors(
          actual: header.numFATSectors,
          expected: maxNumberOfFATSectors
        )
      }
    }

    return fat
  }
}
