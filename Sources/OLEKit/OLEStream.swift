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
    if totalSize == 0 && sectorID == SectorID.endOfChain.rawValue {
      throw OLEError.invalidEmptyOLEStream
    }

    let sectorSize = UInt64(sectorSize)
    let fatCount = UInt64(fat.count)
    let actualSize = totalSize ?? UInt64(fat.count) * sectorSize
    let numberOfSectors = (actualSize + sectorSize - 1) / sectorSize

    // This number should (at least) be less than the total number of
    // sectors in the given FAT:
    guard numberOfSectors < fatCount
    else { throw OLEError.streamTooLarge(actual: numberOfSectors, expected: fatCount) }

    data = Data()
  }
}
