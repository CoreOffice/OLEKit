import Foundation

extension DataStream {
  init(
    oleFile: FileHandle,
    sectorID: UInt32,
    totalSize: UInt64?,
    firstSectorOffset: UInt64,
    sectorSize: UInt16,
    fat: [UInt32]
  ) throws {
    guard !(totalSize == 0 && sectorID == SectorID.endOfChain.rawValue)
    else { throw OLEError.invalidEmptyOLEStream }

    let sectorSize = UInt64(sectorSize)
    let fatCount = UInt64(fat.count)
    let actualSize = totalSize ?? UInt64(fat.count) * sectorSize
    let numberOfSectors = (actualSize + sectorSize - 1) / sectorSize

    // This number should (at least) be less than the total number of
    // sectors in the given FAT:
    guard numberOfSectors < fatCount
    else { throw OLEError.streamTooLarge(actual: numberOfSectors, expected: fatCount) }

    var currentSectorID = sectorID
    for _ in 0..<numberOfSectors {
      guard currentSectorID != SectorID.endOfChain.rawValue else {
        if let totalSize = totalSize {
          // This means that the stream is smaller than declared:
          throw OLEError.incompleteOLEStream(start: sectorID, expected: numberOfSectors)
        } else {
          // Reached end of chain for a stream with unknown size
          break
        }
      }
    }

    data = Data()
  }
}
