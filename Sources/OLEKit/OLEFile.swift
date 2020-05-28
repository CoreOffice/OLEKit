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

public final class OLEFile {
  private var fileHandle: FileHandle
  let header: Header

  /// File Allocation Table, also known as SAT – Sector Allocation Table
  let fat: [UInt32]

  let miniFAT: [UInt32]

  // Can't be `lazy var` because Swift doesn't support throwing properties, and we need
  // to handle (or rethrow) potential errors from `DataStream.init`.
  private var miniStream: DataStream?

  public let root: DirectoryEntry

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

    miniFAT = try fileHandle.loadMiniFAT(header, root: root, fat: fat)
  }

  /// Return an instance of `DataStream` that contains a given stream entry
  public func stream(_ entry: DirectoryEntry) throws -> DataStream {
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
  func streamForceFAT(_ entry: DirectoryEntry) throws -> DataStream {
    try fileHandle.oleStream(
      sectorID: entry.firstStreamSector,
      expectedStreamSize: entry.streamSize,
      firstSectorOffset: UInt64(header.sectorSize),
      sectorSize: header.sectorSize,
      fat: fat
    )
  }
}
