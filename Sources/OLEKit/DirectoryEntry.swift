/**
 OLE2 Directory Entry pointing to a stream or a storage

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
struct DirectoryEntry: Equatable {
  static let sizeInBytes = 128

  let name: String

  init(_ stream: inout DataStream) throws {
    var utf16Name = [UInt16]()
    for _ in 0..<32 {
      utf16Name.append(stream.read())
    }

    // number of bytes used in name buffer, including null
    let bytesWithNull: UInt16 = stream.read()

    name = String(utf16CodeUnits: &utf16Name, count: (Int(bytesWithNull) - 2) / 2)
  }
}
