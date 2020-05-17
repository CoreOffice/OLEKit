import Foundation

struct DataStream {
  let data: Data
  var index = 0

  init(_ data: Data) {
    self.data = data
  }

  mutating func read() -> UInt16 {
    defer { index += 2 }

    return UInt16(data[index + 1]) << 8 + UInt16(data[index])
  }

  mutating func read() -> UInt32 {
    defer { index += 4 }

    return (UInt32(data[index + 3]) << 24)
      + (UInt32(data[index + 2]) << 16)
      + (UInt32(data[index + 1]) << 8)
      + UInt32(data[index])
  }

  mutating func read(count: Int) -> Data {
    defer { index += count }

    return data[index..<index + count]
  }
}
