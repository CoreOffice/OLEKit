import Foundation

/// Helper protocol that presents a unified interface for both `FileHandle` and `DataReader`.
protocol Reader: AnyObject {
  func seek(toOffset: UInt64)
  func readData(ofLength: Int) -> Data
  func readDataToEnd() -> Data
}

extension FileHandle: Reader {
  func seek(toOffset offset: UInt64) { seek(toFileOffset: offset) }
  func readDataToEnd() -> Data { readDataToEndOfFile() }
}
