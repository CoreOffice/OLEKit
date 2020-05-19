import Foundation

/// Magic bytes that should be at the beginning of every OLE file:
private let magic = Data([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])

/**
 Header structure according to AAF specifications:

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
struct Header {
  let minorVersion: UInt16
  let dllVersion: UInt16
  let sectorSize: UInt16
  let miniSectorSize: UInt16

  let numDirectorySectors: UInt32
  let numFATSectors: UInt32
  let firstDirectorySector: UInt32
  let transactionSignatureNumber: UInt32
  let miniStreamCutoffSize: UInt32
  let firstMiniFATSector: UInt32
  let numMiniFATSectors: UInt32
  let firstDIFATSector: UInt32
  let numDIFATSectors: UInt32
  let numberOfSectors: Int

  init(_ stream: inout DataStream, fileSize: Int, url: URL) throws {
    guard stream.read(count: magic.count) == magic else { throw OLEError.fileIsNotOLE(url) }

    // according to AAF specs, CLSID should always be zero
    guard stream.read(count: 16) == Data(repeating: 0, count: 16) else {
      throw OLEError.incorrectCLSID
    }

    // Assuming that OLE headers are little-endian...
    minorVersion = stream.read()
    dllVersion = stream.read()

    // version 3: usual format, 512 bytes per sector
    // version 4: large format, 4K per sector
    guard [3, 4].contains(dllVersion)
    else { throw OLEError.incorrectDLLVersion(actual: dllVersion, expected: [3, 4]) }

    // For now only common little-endian documents are handled correctly
    guard stream.read() as UInt16 == 0xFFFE else { throw OLEError.bigEndianNotSupported }

    let fatSectorShift: UInt16 = stream.read()

    sectorSize = UInt16(pow(Double(2), Double(fatSectorShift)))

    if dllVersion == 3, sectorSize != 512 {
      throw OLEError.incorrectSectorSize(actual: sectorSize, expected: 512)
    }
    if dllVersion == 4, sectorSize != 4096 {
      throw OLEError.incorrectSectorSize(actual: sectorSize, expected: 4096)
    }

    let miniSectorShift: UInt16 = stream.read()

    miniSectorSize = UInt16(pow(Double(2), Double(miniSectorShift)))

    guard miniSectorSize == 64 else {
      throw OLEError.incorrectMiniSectorSize(actual: miniSectorSize, expected: 64)
    }

    guard stream.read() as UInt16 == 0 && stream.read() as UInt32 == 0
    else { throw OLEError.incorrectHeaderReservedBytes }

    // Number of directory sectors (only allowed if DllVersion != 3)
    numDirectorySectors = stream.read()
    if dllVersion == 3, numDirectorySectors != 0 {
      throw OLEError.incorrectNumberOfDirectorySectors(actual: numDirectorySectors, expected: 0)
    }

    numFATSectors = stream.read()
    firstDirectorySector = stream.read()
    transactionSignatureNumber = stream.read()

    // MS-CFB: This integer field MUST be set to 0x00001000. This field
    // specifies the maximum size of a user-defined data stream allocated
    // from the mini FAT and mini stream, and that cutoff is 4096 bytes.
    // Any user-defined data stream larger than or equal to this cutoff size
    // must be allocated as normal sectors from the FAT.
    miniStreamCutoffSize = stream.read()

    guard miniStreamCutoffSize == 0x1000 else {
      throw OLEError.incorrectMiniStreamCutoffSize(
        actual: miniStreamCutoffSize,
        expected: 0x1000
      )
    }

    firstMiniFATSector = stream.read()
    numMiniFATSectors = stream.read()
    firstDIFATSector = stream.read()
    numDIFATSectors = stream.read()

    // -1 because header's sector doesn't count
    numberOfSectors = ((fileSize + Int(sectorSize) - 1) / Int(sectorSize)) - 1
  }
}
