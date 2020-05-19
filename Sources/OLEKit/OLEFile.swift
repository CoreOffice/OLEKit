import Foundation

public enum OLEError: Error, Equatable, CustomStringConvertible {
  case fileIsNotOLE(URL)
  case incorrectCLSID
  case incompleteHeader
  case invalidFATSector(byteOffset: UInt64)
  case incorrectSectorSize(actual: UInt16, expected: UInt16)
  case incorrectDLLVersion(actual: UInt16, expected: [UInt16])
  case bigEndianNotSupported
  case incorrectMiniSectorSize(actual: UInt16, expected: UInt16)
  case incorrectHeaderReservedBytes
  case incorrectMiniStreamCutoffSize(actual: UInt32, expected: UInt32)
  case incorrectNumberOfDirectorySectors(actual: UInt32, expected: UInt32)

  public var description: String {
    switch self {
    case let .fileIsNotOLE(url):
      return "Given file at URL \(url) is not an OLE file"
    case .incorrectCLSID:
      return "CLSID value in the file header is not set according to the spec"
    case .incompleteHeader:
      return "Given file has an incomplete header"
    case let .invalidFATSector(byteOffset):
      return "No sector is available at byte offset \(byteOffset)"
    case let .incorrectSectorSize(actual, expected):
      return
        """
        Incorrect sector size \(actual) inferred from the file header, \
        expected size \(expected)
        """
    case let .incorrectDLLVersion(actual, expected):
      return
        """
        Incorrect DLL version \(actual) in the file header, \
        expected versions are \(expected)
        """
    case .bigEndianNotSupported:
      return "Big endian files are not supported"
    case let .incorrectMiniSectorSize(actual, expected):
      return
        """
        Incorrect mini sector size \(actual) specified in the file header, \
        expected size \(expected)
        """
    case .incorrectHeaderReservedBytes:
      return "Incorrect reserved bytes in the file header, expected those to be zeros"
    case let .incorrectMiniStreamCutoffSize(actual, expected):
      return
        """
        Incorrect mini stream cutoff size \(actual) specified in the file header, \
        expected size \(expected)
        """
    case let .incorrectNumberOfDirectorySectors(actual, expected):
      return
        """
        Incorrect number of directory sectors \(actual) specfied in the file header, \
        expected
        """
    }
  }
}

public final class OLEFile {
  private let fileHandle: FileHandle
  let header: Header

  private let fat: [UInt32]

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

    // FIXME: check DIFAT if file is larger than 6.8MB

    self.fat = fat
  }
}
