import Foundation

struct DataStream {
  let data: Data
  var byteOffset = 0

  init(_ data: Data) {
    self.data = data
  }

  mutating func read() -> UInt8 {
    defer { byteOffset += 1 }

    return data[byteOffset]
  }

  mutating func read() -> UInt16 {
    defer { byteOffset += 2 }

    return UInt16(data[byteOffset + 1]) << 8 + UInt16(data[byteOffset])
  }

  mutating func read() -> UInt32 {
    defer { byteOffset += 4 }

    return (UInt32(data[byteOffset + 3]) << 24)
      + (UInt32(data[byteOffset + 2]) << 16)
      + (UInt32(data[byteOffset + 1]) << 8)
      + UInt32(data[byteOffset])
  }

  mutating func read(count: Int) -> Data {
    defer { byteOffset += count }

    return data[byteOffset..<byteOffset + count]
  }
}
