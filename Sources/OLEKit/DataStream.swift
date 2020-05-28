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

/// A stateful stream that allows reading raw in-memory data in little-endian mode.
public struct DataStream {
  let data: Data

  /// Current byte offset within the stream.
  public var byteOffset = 0

  init(_ data: Data) {
    self.data = data
  }

  /// Read a single byte from the stream and increment `byteOffset` by 1.
  public mutating func read() -> UInt8 {
    defer { byteOffset += 1 }

    return data[byteOffset]
  }

  /// Read two bytes in little-endian order as a single `UInt16` value and
  /// increment `byteOffset` by 2.
  public mutating func read() -> UInt16 {
    defer { byteOffset += 2 }

    return UInt16(data[byteOffset + 1]) << 8 + UInt16(data[byteOffset])
  }

  /// Read four bytes in little-endian order as a single `UInt32` value and
  /// increment `byteOffset` by 4.
  public mutating func read() -> UInt32 {
    defer { byteOffset += 4 }

    return (UInt32(data[byteOffset + 3]) << 24)
      + (UInt32(data[byteOffset + 2]) << 16)
      + (UInt32(data[byteOffset + 1]) << 8)
      + UInt32(data[byteOffset])
  }

  /// Read a given `count` of bytes as raw data and increment `byteOffset` by `count`.
  public mutating func read(count: Int) -> Data {
    defer { byteOffset += count }

    return data[byteOffset..<byteOffset + count]
  }
}
