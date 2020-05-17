/// Constants for Sector IDs (from AAF specifications)
enum SectorID: UInt32 {
  /// (-6) maximum SECT
  case maximumSector = 0xFFFF_FFFA

  /// (-4) denotes a DIFAT sector in a FAT
  case difatSector = 0xFFFF_FFFC

  /// (-3) denotes a FAT sector in a FAT
  case fatSector = 0xFFFF_FFFD

  ///  (-2) end of a virtual stream chain
  case endOfChain = 0xFFFF_FFFE

  ///  (-1) unallocated sector
  case freeSector = 0xFFFF_FFFF
}
