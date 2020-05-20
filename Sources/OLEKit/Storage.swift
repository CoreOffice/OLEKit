/// Object types in storage (from AAF specifications)
public enum StorageType: UInt8 {
  /// Empty directory entry
  case empty = 0

  /// Storage object
  case storage = 1

  /// Stream object
  case stream = 2

  /// `ILockBytes` object
  case lockBytes = 3

  /// `IPropertyStorage` object
  case property = 4

  /// Root storage
  case root = 5
}
