import Foundation

func loadDirectory(
  at sectorID: UInt32,
  in fileHandle: FileHandle,
  _ header: Header,
  fat: [UInt32]
) throws -> DataStream {
  try DataStream(
    fileHandle,
    sectorID: sectorID,
    firstSectorOffset: UInt64(header.sectorSize),
    sectorSize: header.sectorSize,
    fat: fat
  )
}

public final class OLEFile {
  private let fileHandle: FileHandle
  let header: Header

  /// File Allocation Table, also known as: SAT – Sector Allocation Table
  private let fat: [UInt32]

  let root: DirectoryEntry

  public init(_ url: URL) throws {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    // swiftlint:disable:next force_cast
    let fileSize = attributes[FileAttributeKey.size] as! Int

    fileHandle = try FileHandle(forReadingFrom: url)

    guard fileSize >= 512
    else { throw OLEError.incompleteHeader }

    let data = fileHandle.readData(ofLength: 512)

    var stream = DataStream(data)
    header = try Header(&stream, fileSize: fileSize, url: url)

    // The 1st sector of the file contains sector numbers for the first 109
    // FAT sectors, right after the header which is 76 bytes long.
    // (always 109, whatever the sector size: 512 bytes = 76+4*109)
    // Additional sectors are described by DIF blocks
    var fat = [UInt32]()
    for _ in 0..<109 {
      let sectorIndex: UInt32 = stream.read()

      guard sectorIndex != SectorID.endOfChain.rawValue &&
        sectorIndex != SectorID.freeSector.rawValue
      else { break }

      let sectorOffset = UInt64(header.sectorSize) * UInt64(sectorIndex + 1)

      guard sectorOffset < fileSize
      else { throw OLEError.invalidFATSector(byteOffset: sectorOffset) }

      fileHandle.seek(toFileOffset: sectorOffset)
      var sectorStream = DataStream(fileHandle.readData(ofLength: Int(header.sectorSize)))
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

    // FIXME: check Double-Indirect File Allocation Table (DIFAT) if file is larger
    // than 6.8MB

    self.fat = fat

    root = try DirectoryEntry(
      rootAt: header.firstDirectorySector,
      in: fileHandle,
      header,
      fat: fat
    )
  }
}
