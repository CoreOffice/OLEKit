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
