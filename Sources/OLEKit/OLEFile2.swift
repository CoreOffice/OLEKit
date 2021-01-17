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

#if os(iOS) || os(watchOS) || os(tvOS) || os(macOS)

public final class OLEFile2 {
  private var fileWrapper: FileWrapper
  let header: Header

  /// File Allocation Table, also known as SAT – Sector Allocation Table
  let fat: [UInt32]

  let miniFAT: [UInt32]

  // Can't be `lazy var` because Swift doesn't support throwing properties, and we need
  // to handle (or rethrow) potential errors from `DataReader.init`.
  private var miniStream: DataReader?

  public let root: DirectoryEntry

  public init(_ fileWrapper: FileWrapper) throws {
    self.fileWrapper = fileWrapper

    guard let data = fileWrapper.regularFileContents
    else { throw OLEError.fileDoesNotExist(fileWrapper.filename ?? "") }

    var stream = DataReader(data[..<512])
    guard let fileSize = fileWrapper.fileAttributes[FileAttributeKey.size.rawValue] as? Int
    else { throw OLEError.fileDoesNotExist(fileWrapper.filename ?? "") }
    header = try Header(&stream, fileSize: fileSize, path: fileWrapper.filename ?? "")

    fat = try fileWrapper.loadFAT(headerStream: &stream, header)

    root = try DirectoryEntry.entries(
      rootAt: header.firstDirectorySector,
      in: fileWrapper,
      header,
      fat: fat
    )[0]

    miniFAT = try fileWrapper.loadMiniFAT(header, root: root, fat: fat)
  }

  /// Return an instance of `DataReader` that contains a given stream entry
  public func stream(_ entry: DirectoryEntry) throws -> DataReader {
    guard entry.type == .stream
    else { throw OLEError.directoryEntryIsNotAStream(name: entry.name) }

    if entry.streamSize < header.miniStreamCutoffSize {
      let miniStream = try self.miniStream ?? streamForceFAT(root)

      // cache miniStream
      if self.miniStream == nil {
        self.miniStream = miniStream
      }

      return try miniStream.oleStream(
        sectorID: entry.firstStreamSector,
        expectedStreamSize: entry.streamSize,
        firstSectorOffset: 0,
        sectorSize: header.miniSectorSize,
        fat: miniFAT
      )
    } else {
      return try streamForceFAT(entry)
    }
  }

  /// Always loads data according to FAT ignoring `miniStream` and `miniFAT`
  func streamForceFAT(_ entry: DirectoryEntry) throws -> DataReader {
    try fileWrapper.oleStream(
      sectorID: entry.firstStreamSector,
      expectedStreamSize: entry.streamSize,
      firstSectorOffset: UInt64(header.sectorSize),
      sectorSize: header.sectorSize,
      fat: fat
    )
  }
}

#endif
