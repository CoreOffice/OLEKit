// Copyright 2020 CoreOffice contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

public enum OLEError: Error, Equatable, CustomStringConvertible {
  case incorrectCLSID
  case incompleteHeader
  case duplicateRootEntry
  case invalidEmptyStream
  case bigEndianNotSupported
  case fileIsNotOLE(String)
  case fileDoesNotExist(String)
  case incorrectHeaderReservedBytes
  case incorrectStorageType(actual: UInt8)
  case invalidFATSector(byteOffset: UInt64)
  case incorrectRootEntry(actual: StorageType)
  case directoryEntryIsNotAStream(name: String)
  case fileNotAvailableForReading(path: String)
  case incorrectDirectoryEntryColor(actual: UInt8)
  case streamTooLarge(actual: UInt64, expected: Int)
  case invalidOLEStreamSectorID(id: UInt32, total: Int)
  case sectorIndexInDIFATOOB(actual: UInt32, expected: Int)
  case incorrectSectorSize(actual: UInt16, expected: UInt16)
  case directoryEntryIndexOOB(actual: UInt32, expected: Int)
  case incorrectDLLVersion(actual: UInt16, expected: [UInt16])
  case incorrectMiniSectorSize(actual: UInt16, expected: UInt16)
  case incorrectNumberOfFATSectors(actual: UInt32, expected: UInt32)
  case incorrectNumberOFDIFATSectors(actual: UInt32, expected: UInt32)
  case incorrectMiniStreamCutoffSize(actual: UInt32, expected: UInt32)
  case incompleteStream(firstSectorID: UInt32, actual: Int, expected: UInt64)
  case incorrectNumberOfDirectorySectors(actual: UInt32, expected: UInt32)

  public var description: String {
    switch self {
    case .incorrectCLSID:
      return "CLSID value in the file header is not set according to the spec"
    case .incompleteHeader:
      return "Given file has an incomplete header"
    case .duplicateRootEntry:
      return "Duplicate OLE root directory entry stored in the file"
    case .invalidEmptyStream:
      return "Incorrect OLE sector index for empty stream"
    case let .fileIsNotOLE(path):
      return "Given file at path \(path) is not an OLE file"
    case .bigEndianNotSupported:
      return "Big endian files are not supported"
    case let .fileDoesNotExist(path):
      return "File does not exist at path \(path)"
    case .incorrectHeaderReservedBytes:
      return "Incorrect reserved bytes in the file header, expected those to be zeros"
    case let .incorrectRootEntry(actual):
      return
        """
        Incorrect OLE root directory entry stored in the file with type \(actual), \
        expected type \(StorageType.root.rawValue)
        """
    case let .incorrectStorageType(actual):
      return "Incorrect OLE storage type \(actual), expected a number in 0...5 range"
    case let .directoryEntryIsNotAStream(name):
      return #"Directory entry with name "\#(name)" is not of stream type"#
    case let .fileNotAvailableForReading(path):
      return "File is not available for reading at path \(path)"
    case let .invalidOLEStreamSectorID(id, total):
      return "Incorrect OLE FAT, sectorID \(id) is out of total bounds of \(total) sectors"
    case let .sectorIndexInDIFATOOB(actual, expected):
      return "Sector index \(actual) is out of bounds, expected to not to exceed \(expected)"
    case let .invalidFATSector(byteOffset):
      return "No sector is available at byte offset \(byteOffset)"
    case let .incompleteStream(sectorID, actual, expected):
      return
        """
        Incomplete OLE stream that starts at sector \(sectorID),
        expected it to contain at least \(expected) bytes, but its size is \(actual) bytes
        """
    case let .streamTooLarge(actual, expected):
      return
        """
        Malformed OLE document, stream too large with \(actual) sectors,
        expected \(expected)
        """
    case let .incorrectDirectoryEntryColor(actual):
      return "Incorrect OLE directory entry color \(actual), expected either 0 or 1"
    case let .incorrectSectorSize(actual, expected):
      return
        """
        Incorrect sector size \(actual) inferred from the file header, \
        expected size \(expected)
        """
    case let .directoryEntryIndexOOB(actual, expected):
      return
        """
        Index \(actual) of a directory entry is out of range, expected it not to exceed \(expected)
        """
    case let .incorrectDLLVersion(actual, expected):
      return
        """
        Incorrect DLL version \(actual) in the file header, \
        expected versions are \(expected)
        """
    case let .incorrectNumberOfFATSectors(actual, expected):
      return "Incorrect number of FAT sectors, expected at least \(expected), but got \(actual)"
    case let .incorrectNumberOFDIFATSectors(actual, expected):
      return "Incorrect number of DIFFAT sectors, expected \(expected), but got \(actual)"
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
