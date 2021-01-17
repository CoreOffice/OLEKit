import Foundation

#if os(iOS) || os(watchOS) || os(tvOS) || os(macOS)

extension FileWrapper: Reader {
  func seek(toOffset: Int) {
    seek(toOffset: toOffset)
  }

  func readData(ofLength: Int) -> Data {
    readData(ofLength: ofLength)
  }

  func readDataToEnd() -> Data {
    readDataToEnd()
  }

  func loadSector(_ header: Header, index: UInt32) throws -> DataReader {
    let sectorOffset = Int(header.sectorSize) * Int(index + 1)

    guard sectorOffset < header.fileSize
    else { throw OLEError.invalidFATSector(byteOffset: UInt64(sectorOffset)) }

    let range = sectorOffset..<(sectorOffset + Int(header.sectorSize))
    return DataReader(regularFileContents![range])
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

  func oleStream(
    sectorID: UInt32,
    expectedStreamSize: UInt64? = nil,
    firstSectorOffset: UInt64,
    sectorSize: UInt16,
    fat: [UInt32]
  ) throws -> DataReader {
    guard !(expectedStreamSize == 0 && sectorID == SectorID.endOfChain.rawValue)
    else { throw OLEError.invalidEmptyStream }

    let sectorSize = UInt64(sectorSize)
    let calculatedStreamSize = expectedStreamSize ?? UInt64(fat.count) * UInt64(sectorSize)
    let numberOfSectors = (calculatedStreamSize + sectorSize - 1) / sectorSize

    // This number should (at least) be less than the total number of
    // sectors in the given FAT:
    guard numberOfSectors <= fat.count
    else { throw OLEError.streamTooLarge(actual: numberOfSectors, expected: fat.count) }

    var currentSectorID = sectorID
    var data = Data()
    var offset = regularFileContents!.startIndex
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

      offset = regularFileContents!.startIndex + Int(firstSectorOffset) + Int(sectorSize) * Int(currentSectorID)

      // if sector is the last of the file, sometimes it is not a
      // complete sector (of 512 or 4K), so we may read less than
      // sectorsize.
      if currentSectorID == fat.count - 1 {
        data.append(regularFileContents![offset..<regularFileContents!.endIndex])
      } else {
        data.append(regularFileContents![offset..<(offset + Int(sectorSize))])
      }

      currentSectorID = fat[Int(currentSectorID)]
    }

    if data.count > calculatedStreamSize {
      // `data` is truncated to the expected stream size
      data = data.prefix(Int(calculatedStreamSize))
    } else if let expectedStreamSize = expectedStreamSize, data.count < expectedStreamSize {
      // the stream size was not inferred, but was smaller than expected
      throw OLEError.incompleteStream(
        firstSectorID: sectorID,
        actual: data.count,
        expected: expectedStreamSize
      )
    }

    return DataReader(data)
  }
}

#endif
