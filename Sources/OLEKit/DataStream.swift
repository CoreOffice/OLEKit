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

public final class DataWriter {
  public private(set) var data = Data()

  public init() {}

  // Write four bytes in little-endian order to this stream
  public func write(_ value: UInt32) {
    var value = value.littleEndian
    data.append(contentsOf: withUnsafeBytes(of: &value) { Array($0) })
  }
}

/// A stateful stream that allows reading raw in-memory data in little-endian mode.
public final class DataReader: Reader {
  let data: Data

  /// Current byte offset within the stream.
  var byteOffset = 0

  init(_ data: Data) {
    self.data = data
  }

  public var totalBytes: Int {
    data.count
  }

  public func seek(toOffset offset: Int) {
    precondition(offset < data.count)

    byteOffset = offset
  }

  /// Read a single byte from the stream and increment `byteOffset` by 1.
  public func read() -> UInt8 {
    precondition(byteOffset + 1 <= data.count)
    defer { byteOffset += 1 }

    return data[data.startIndex + byteOffset]
  }

  /// Read two bytes in little-endian order as a single `UInt16` value and
  /// increment `byteOffset` by 2.
  public func read() -> UInt16 {
    precondition(byteOffset + 2 <= data.count)
    defer { byteOffset += 2 }

    return (UInt16(data[data.startIndex + byteOffset + 1]) << 8) + UInt16(data[data.startIndex + byteOffset])
  }

  /// Read four bytes in little-endian order as a single `UInt32` value and
  /// increment `byteOffset` by 4.
  public func read() -> UInt32 {
    precondition(byteOffset + 4 <= data.count)
    defer { byteOffset += 4 }

    return (UInt32(data[data.startIndex + byteOffset + 3]) << 24)
      + (UInt32(data[data.startIndex + byteOffset + 2]) << 16)
      + (UInt32(data[data.startIndex + byteOffset + 1]) << 8)
      + UInt32(data[data.startIndex + byteOffset])
  }

  /// Read a given `count` of bytes as raw data and increment `byteOffset` by `count`.
  public func readData(ofLength length: Int) -> Data {
    precondition(byteOffset + length <= data.count)
    defer { byteOffset += length }

    return data[data.startIndex + byteOffset..<data.startIndex + byteOffset + length]
  }

  public func readDataToEnd() -> Data {
    guard data.count > 0 else { return data }

    defer { byteOffset = data.count - 1 }

    return data[data.startIndex + byteOffset..<data.endIndex]
  }
}
