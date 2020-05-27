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

  /// File Allocation Table, also known as SAT – Sector Allocation Table
  let fat: [UInt32]

  let root: DirectoryEntry

  public init(_ path: String) throws {
    guard FileManager.default.fileExists(atPath: path)
    else { throw OLEError.fileDoesNotExist(path) }

    let attributes = try FileManager.default.attributesOfItem(atPath: path)
    // swiftlint:disable:next force_cast
    let fileSize = attributes[FileAttributeKey.size] as! Int

    guard let fileHandle = FileHandle(forReadingAtPath: path)
    else { throw OLEError.fileNotAvailableForReading(path: path) }

    self.fileHandle = fileHandle

    guard fileSize >= 512
    else { throw OLEError.incompleteHeader }

    let data = fileHandle.readData(ofLength: 512)

    var stream = DataStream(data)
    header = try Header(&stream, fileSize: fileSize, path: path)

    fat = try fileHandle.loadFAT(headerStream: &stream, header)

    root = try DirectoryEntry(
      rootAt: header.firstDirectorySector,
      in: fileHandle,
      header,
      fat: fat
    )
  }
}
