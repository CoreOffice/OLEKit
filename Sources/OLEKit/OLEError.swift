import Foundation

public enum OLEError: Error, Equatable, CustomStringConvertible {
  case fileIsNotOLE(URL)
  case incorrectCLSID
  case incompleteHeader
  case invalidEmptyOLEStream
  case bigEndianNotSupported
  case incorrectHeaderReservedBytes
  case invalidFATSector(byteOffset: UInt64)
  case streamTooLarge(actual: Int, expected: Int)
  case invalidOLEStreamSectorID(id: UInt32, total: Int)
  case incorrectSectorSize(actual: UInt16, expected: UInt16)
  case incorrectDLLVersion(actual: UInt16, expected: [UInt16])
  case incorrectMiniSectorSize(actual: UInt16, expected: UInt16)
  case incorrectMiniStreamCutoffSize(actual: UInt32, expected: UInt32)
  case incompleteOLEStream(firstSectorID: UInt32, actual: Int, expected: Int)
  case incorrectNumberOfDirectorySectors(actual: UInt32, expected: UInt32)

  public var description: String {
    switch self {
    case let .fileIsNotOLE(url):
      return "Given file at URL \(url) is not an OLE file"
    case .incorrectCLSID:
      return "CLSID value in the file header is not set according to the spec"
    case .incompleteHeader:
      return "Given file has an incomplete header"
    case .invalidEmptyOLEStream:
      return "Incorrect OLE sector index for empty stream"
    case .bigEndianNotSupported:
      return "Big endian files are not supported"
    case .incorrectHeaderReservedBytes:
      return "Incorrect reserved bytes in the file header, expected those to be zeros"
    case let .invalidOLEStreamSectorID(id, total):
      return "Incorrect OLE FAT, sectorID \(id) is out of total bounds of \(total) sectors"
    case let .invalidFATSector(byteOffset):
      return "No sector is available at byte offset \(byteOffset)"
    case let .incompleteOLEStream(sectorID, actual, expected):
      return
        """
        Incomplete OLE stream that starts at sector \(sectorID),
        expected it to contain at least \(expected) bytes. but its size is \(actual) bytes
        """
    case let .streamTooLarge(actual, expected):
      return
        """
        Malformed OLE document, stream too large with \(actual) sectors,
        expected \(expected)
        """
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
    case let .incorrectMiniSectorSize(actual, expected):
      return
        """
        Incorrect mini sector size \(actual) specified in the file header, \
        expected size \(expected)
        """
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
        expected \(expected)
        """
    }
  }
}
