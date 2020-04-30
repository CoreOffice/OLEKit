import Foundation

/// Magic bytes that should be at the beginning of every OLE file:
private let magic = Data([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])

public extension FileHandle {
  /** Test if a file is an OLE container (according to the magic bytes in its header).
   This only checks the first 8 bytes of the file, not the
   rest of the OLE structure.
   */
  func isOLE() throws -> Bool {
    try seek(toOffset: 0)

    return try read(upToCount: magic.count) == magic
  }
}
