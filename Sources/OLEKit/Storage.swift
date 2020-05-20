/// Object types in storage (from AAF specifications)
enum StorageType: Int {
  /// Empty directory entry
  case empty

  /// Storage object
  case storage

  /// Stream object
  case stream

  /// `ILockBytes` object
  case lockBytes

  /// `IPropertyStorage` object
  case property

  /// Root storage
  case root
}
