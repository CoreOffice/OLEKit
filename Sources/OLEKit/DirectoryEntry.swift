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

private let noStream: UInt32 = 0xFFFF_FFFF

/*
 struct to parse directory entries: '<64sHBBIII16sIQQIII'
 <: little-endian byte order, standard sizes
   (note: this should guarantee that Q returns a 64 bits int)
 64s: string containing entry name in unicode UTF-16 (max 31 chars) + null char = 64 bytes
 H: uint16, number of bytes used in name buffer, including null = (len+1)*2
 B: uint8, dir entry type (between 0 and 5, parsed as `StorageType`)
 B: uint8, color: 0=black, 1=red
 I: uint32, index of left child node in the red-black tree, NOSTREAM if none
 I: uint32, index of right child node in the red-black tree, NOSTREAM if none
 I: uint32, index of child root node if it is a storage, else NOSTREAM
 16s: CLSID, unique identifier (only used if it is a storage)
 I: uint32, user flags
 Q (was 8s): uint64, creation timestamp or zero
 Q (was 8s): uint64, modification timestamp or zero
 I: uint32, SID of first sector if stream or ministream, SID of 1st sector
   of stream containing ministreams if root entry, 0 otherwise
 I: uint32, total stream size in bytes if stream (low 32 bits), 0 otherwise
 I: uint32, total stream size in bytes if stream (high 32 bits), 0 otherwise
 */
/**
 OLE2 Directory Entry pointing to a stream or a storage.
 */
public struct DirectoryEntry: Equatable {
  enum Color: UInt8 {
    case black = 0
    case red = 1
  }

  static let sizeInBytes = 128

  public let name: String
  public let type: StorageType

  // Directory entries are organised as a
  // [red-black tree](https://en.wikipedia.org/wiki/Red%E2%80%93black_tree)
  let leftIndex: UInt32
  let rightIndex: UInt32
  let childIndex: UInt32

  public let firstStreamSector: UInt32
  public let streamSize: UInt64

  public let children: [DirectoryEntry]

  private init?(
    _ stream: inout DataReader,
    _ peers: inout [DirectoryEntry],
    index: UInt32,
    sectorSize: UInt16
  ) throws {
    guard index != noStream else { return nil }

    stream.byteOffset = Int(index) * Self.sizeInBytes

    var utf16Name = [UInt16]()
    for _ in 0..<32 {
      utf16Name.append(stream.read())
    }

    // number of bytes used in name buffer, including null
    let bytesWithNull: UInt16 = stream.read()

    name = String(utf16CodeUnits: &utf16Name, count: (Int(bytesWithNull) - 2) / 2)

    let rawType: UInt8 = stream.read()
    guard let type = StorageType(rawValue: rawType)
    else { throw OLEError.incorrectStorageType(actual: rawType) }

    self.type = type

    guard !(type == .root && index != 0) else { throw OLEError.duplicateRootEntry }
    guard !(index == 0 && type != .root) else { throw OLEError.incorrectRootEntry(actual: type) }

    // color value is unused, but still checked
    let rawColor: UInt8 = stream.read()
    guard Color(rawValue: rawColor) != nil
    else { throw OLEError.incorrectDirectoryEntryColor(actual: rawColor) }

    leftIndex = stream.read()
    rightIndex = stream.read()
    childIndex = stream.read()

    // FIXME: skipping clsid, which is unused for now
    stream.byteOffset += 16

    // FIXME: skipping user flags (4 bytes) and timestamps (16 bytes)
    stream.byteOffset += 20

    firstStreamSector = stream.read()

    let sizeLowBits: UInt32 = stream.read()
    let sizeHighBits: UInt32 = stream.read()

    // sizeHighBits is only used for 4K sectors, it should be zero for 512 bytes
    // sectors, BUT apparently some implementations set it as 0xFFFFFFFF, 1
    // or some other value so it cannot be raised as a defect in general
    if sectorSize == 512 {
      streamSize = UInt64(sizeLowBits)
    } else {
      streamSize = UInt64(sizeLowBits) + (UInt64(sizeHighBits) << 32)
    }

    // To detect malformed documents the maximum number of directory entries
    // can be calculated.
    let maxEntries = stream.data.count / DirectoryEntry.sizeInBytes

    let idx = childIndex
    guard idx == noStream || idx < maxEntries
    else { throw OLEError.directoryEntryIndexOOB(actual: childIndex, expected: maxEntries) }

    if let leftPeer = try DirectoryEntry(&stream, &peers, index: leftIndex, sectorSize: sectorSize) {
      peers.append(leftPeer)
    }
    if let rightPeer = try DirectoryEntry(&stream, &peers, index: rightIndex, sectorSize: sectorSize) {
      peers.append(rightPeer)
    }

    var children = [DirectoryEntry]()
    if let child = try DirectoryEntry(&stream, &children, index: childIndex, sectorSize: sectorSize) {
      children.append(child)
    }
    self.children = children
  }

  private static func entries(
    index: UInt32,
    at sectorID: UInt32,
    in reader: Reader,
    _ header: Header,
    fat: [UInt32]
  ) throws -> [DirectoryEntry] {
    var stream = try reader.oleStream(
      sectorID: sectorID,
      firstSectorOffset: UInt64(header.sectorSize),
      sectorSize: header.sectorSize,
      fat: fat
    )
    var peers = [DirectoryEntry]()

    if let entry = try DirectoryEntry(&stream, &peers, index: index, sectorSize: header.sectorSize) {
      peers.append(entry)
    }
    return peers
  }

  static func entries(
    rootAt sectorID: UInt32,
    in reader: Reader,
    _ header: Header,
    fat: [UInt32]
  ) throws -> [DirectoryEntry] {
    try Self.entries(index: 0, at: sectorID, in: reader, header, fat: fat)
  }
}
