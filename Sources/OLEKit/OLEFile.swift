import Foundation

enum OLEError: Error, Equatable {
  case fileIsNotOLE
  case incorrectCLSID
  case incompleteHeader
  case incorrectSectorSize
  case incorrectDLLVersion
  case bigEndianNotSupported
  case incorrectMiniSectorSize
  case incorrectHeaderReservedBytes
  case incorrectMiniStreamCutoffSize
  case incorrectNumberOfDirectorySectors
}

public final class OLEFile {
  private let fileHandle: FileHandle
  public let header: Header

  public init(_ url: URL) throws {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    // swiftlint:disable:next force_cast
    let fileSize = attributes[FileAttributeKey.size] as! UInt64

    fileHandle = try FileHandle(forReadingFrom: url)

    guard let data = try fileHandle.read(upToCount: 512)
    else { throw OLEError.incompleteHeader }

    var stream = DataStream(data)
    header = try Header(&stream, fileSize: fileSize)
  }
}
