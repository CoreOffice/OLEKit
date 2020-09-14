import Foundation

/// Helper protocol that presents a unified interface for both `FileHandle` and `DataReader`.
protocol Reader: AnyObject {
  func seek(toOffset: Int)
  func readData(ofLength: Int) -> Data
  func readDataToEnd() -> Data
}

extension FileHandle: Reader {
  func seek(toOffset offset: Int) { seek(toFileOffset: UInt64(offset)) }
  func readDataToEnd() -> Data { readDataToEndOfFile() }
}
