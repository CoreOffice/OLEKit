import Foundation

/// Helper protocol that presents a unified interface for `FileHandle`, `FileWrapper` and `DataReader`.
protocol Reader: AnyObject {
  func seek(toOffset: Int)
  func readData(ofLength: Int) -> Data
  func readDataToEnd() -> Data
}
