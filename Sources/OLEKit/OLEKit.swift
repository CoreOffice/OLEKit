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

private extension FileHandle {
  func readLEUInt16() throws -> UInt16 {
    guard let data = try read(upToCount: 2) else { throw OLEError.incompleteHeader }

    return UInt16(data[1]) << 8 + UInt16(data[0])
  }

  func readLEUInt32() throws -> UInt32 {
    guard let data = try read(upToCount: 4) else { throw OLEError.incompleteHeader }

    return (UInt32(data[3]) << 24) + (UInt32(data[2]) << 16) + (UInt32(data[1]) << 8) + UInt32(data[0])
  }
}

enum OLEError: Error {
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

/**
 [PL] header structure according to AAF specifications:

 typedef unsigned long ULONG;    // 4 Bytes
 typedef unsigned short USHORT;  // 2 Bytes
 typedef short OFFSET;           // 2 Bytes
 typedef ULONG SECT;             // 4 Bytes
 typedef ULONG FSINDEX;          // 4 Bytes
 typedef USHORT FSOFFSET;        // 2 Bytes
 typedef USHORT WCHAR;           // 2 Bytes
 typedef ULONG DFSIGNATURE;      // 4 Bytes
 typedef unsigned char BYTE;     // 1 Byte
 typedef unsigned short WORD;    // 2 Bytes
 typedef unsigned long DWORD;    // 4 Bytes
 typedef ULONG SID;              // 4 Bytes
 typedef GUID CLSID;             // 16 Bytes

 struct StructuredStorageHeader { // [offset from start (bytes), length (bytes)]
 BYTE _abSig[8]; // [00H,08] {0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1,
                 // 0x1a, 0xe1} for current version
 CLSID _clsid;   // [08H,16] reserved must be zero (WriteClassStg/
                 // GetClassFile uses root directory class id)
 USHORT _uMinorVersion; // [18H,02] minor version of the format: 33 is
                        // written by reference implementation
 USHORT _uDllVersion;   // [1AH,02] major version of the dll/format: 3 for
                        // 512-byte sectors, 4 for 4 KB sectors
 USHORT _uByteOrder;    // [1CH,02] 0xFFFE: indicates Intel byte-ordering
 USHORT _uSectorShift;  // [1EH,02] size of sectors in power-of-two;
                        // typically 9 indicating 512-byte sectors
 USHORT _uMiniSectorShift; // [20H,02] size of mini-sectors in power-of-two;
                           // typically 6 indicating 64-byte mini-sectors
 USHORT _usReserved; // [22H,02] reserved, must be zero
 ULONG _ulReserved1; // [24H,04] reserved, must be zero
 FSINDEX _csectDir; // [28H,04] must be zero for 512-byte sectors,
                    // number of SECTs in directory chain for 4 KB
                    // sectors
 FSINDEX _csectFat; // [2CH,04] number of SECTs in the FAT chain
 SECT _sectDirStart; // [30H,04] first SECT in the directory chain
 DFSIGNATURE _signature; // [34H,04] signature used for transactions; must
                         // be zero. The reference implementation
                         // does not support transactions
 ULONG _ulMiniSectorCutoff; // [38H,04] maximum size for a mini stream;
                           // typically 4096 bytes
 SECT _sectMiniFatStart; // [3CH,04] first SECT in the MiniFAT chain
 FSINDEX _csectMiniFat; // [40H,04] number of SECTs in the MiniFAT chain
 SECT _sectDifStart; // [44H,04] first SECT in the DIFAT chain
 FSINDEX _csectDif; // [48H,04] number of SECTs in the DIFAT chain
 SECT _sectFat[109]; // [4CH,436] the SECTs of first 109 FAT sectors
 };
 */
public final class OLEFile {
  private let fileHandle: FileHandle

  public let minorVersion: UInt16
  public let dllVersion: UInt16
  public let sectorSize: UInt16
  public let miniSectorSize: UInt16

  public let numDirectorySectors: UInt32
  public let numFATSectors: UInt32
  public let firstDirectorySector: UInt32
  public let transactionSignatureNumber: UInt32
  public let miniStreamCutoffSize: UInt32
  public let firstMiniFATSector: UInt32
  public let numMiniFATSectors: UInt32
  public let firstDIFATSector: UInt32
  public let numDIFATSectors: UInt32
  public let numberOfSectors: UInt64

  public init(_ url: URL) throws {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    // swiftlint:disable:next force_cast
    let fileSize = attributes[FileAttributeKey.size] as! UInt64

    fileHandle = try FileHandle(forReadingFrom: url)

    guard try fileHandle.isOLE() else { throw OLEError.fileIsNotOLE }

    // according to AAF specs, CLSID should always be zero
    guard try fileHandle.read(upToCount: 16) == Data(repeating: 0, count: 16) else {
      throw OLEError.incorrectCLSID
    }

    // Assuming that OLE headers are little-endian...
    minorVersion = try fileHandle.readLEUInt16()
    dllVersion = try fileHandle.readLEUInt16()

    // version 3: usual format, 512 bytes per sector
    // version 4: large format, 4K per sector
    guard [3, 4].contains(dllVersion) else { throw OLEError.incorrectDLLVersion }

    // For now only common little-endian documents are handled correctly
    guard try fileHandle.readLEUInt16() == 0xFFFE else { throw OLEError.bigEndianNotSupported }

    let fatSectorShift = try Double(fileHandle.readLEUInt16())

    sectorSize = UInt16(pow(Double(2), fatSectorShift))

    guard [512, 4096].contains(sectorSize) else { throw OLEError.incorrectSectorSize }

    if dllVersion == 3, sectorSize != 512 { throw OLEError.incorrectSectorSize }
    if dllVersion == 4, sectorSize != 4096 { throw OLEError.incorrectSectorSize }

    let miniFATSectorShift = try Double(fileHandle.readLEUInt16())

    miniSectorSize = UInt16(pow(Double(2), miniFATSectorShift))

    guard miniSectorSize == 64 else { throw OLEError.incorrectMiniSectorSize }

    guard try fileHandle.readLEUInt16() == 0, try fileHandle.readLEUInt32() == 0
    else { throw OLEError.incorrectHeaderReservedBytes }

    // Number of directory sectors (only allowed if DllVersion != 3)
    numDirectorySectors = try fileHandle.readLEUInt32()
    if dllVersion == 3, numDirectorySectors != 0 {
      throw OLEError.incorrectNumberOfDirectorySectors
    }

    numFATSectors = try fileHandle.readLEUInt32()
    firstDirectorySector = try fileHandle.readLEUInt32()
    transactionSignatureNumber = try fileHandle.readLEUInt32()

    // MS-CFB: This integer field MUST be set to 0x00001000. This field
    // specifies the maximum size of a user-defined data stream allocated
    // from the mini FAT and mini stream, and that cutoff is 4096 bytes.
    // Any user-defined data stream larger than or equal to this cutoff size
    // must be allocated as normal sectors from the FAT.
    miniStreamCutoffSize = try fileHandle.readLEUInt32()

    guard miniStreamCutoffSize == 0x1000 else { throw OLEError.incorrectMiniStreamCutoffSize }

    firstMiniFATSector = try fileHandle.readLEUInt32()
    numMiniFATSectors = try fileHandle.readLEUInt32()
    firstDIFATSector = try fileHandle.readLEUInt32()
    numDIFATSectors = try fileHandle.readLEUInt32()

    // -1 because header doesn't count
    numberOfSectors = ((fileSize + UInt64(sectorSize) - 1) / UInt64(sectorSize)) - 1
  }
}
