# OLEKit

Swift support for Microsoft OLE2 format, also known as Structured Storage, [Compound File Binary Format](https://en.wikipedia.org/wiki/Compound_File_Binary_Format) or Compound Document File Format.

Some of the file formats that utilize it:

- Encrypted Office Open XML documents (Microsoft Office 2003+, Word `.docx`, Excel `.xlsx`, PowerPoint `.pptx`)
- Microsoft Office 97-2003 documents ([BIFF5 and later](https://www.gaia-gis.it/gaia-sins/freexl-1.0.5-doxy-doc/html/Format.html) in Word `.doc`, Excel `.xls`, PowerPoint `.ppt`, Visio `.vsd`, Project `.mpp`)
- `vbaProject.bin` in MS Office 2007+ files
- Image Composer and FlashPix files
- Outlook messages
- StickyNotes
- Zeiss AxioVision ZVI files
- Olympus FluoView OIB files
- McAfee antivirus quarantine files
- Hancom Word's `.hwp` file format

...and more. If you know of a file format that is based on CFBF, please submit [a pull request](https://github.com/MaxDesiatov/OLEKit/edit/master/README.md) so that it's added to the list.

Automatically generated documentation is available on [our GitHub Pages](https://coreoffice.github.io/OLEKit/).

## Example

An OLE2 file has [a minuature filesystem embedded in
it](https://en.wikipedia.org/wiki/Compound_File_Binary_Format#Structure) that is
represented as a tree of
[`DirectoryEntry`](https://github.com/CoreOffice/OLEKit/blob/master/Sources/OLEKit/DirectoryEntry.swift)
values in OLEKit.

To read a file and an entry within the file:

1. Add `import OLEKit` at the top of a relevant source file.
2. Use `OLEFile(_ path: String)` to create a new instance with a path to your OLE2 file.
3. Use the `root` property of type `DirectoryEntry` on `OLEFile` to read the root
   directory entry, and the `children` property on `DirectoryEntry` to traverse the tree of
   entries.
4. Call `stream(_ entry:)` on your `OLEFile` instance to get access to the entry.
   This returns an instance of `DataReader` that provides helper `read()` functions
   for reading raw data.

```swift
import OLEKit

let filepath = "./categories.xlsx"
let entryName = "EncryptionInfo"

let ole = try OLEFile(filepath)
guard
  let infoEntry = oleFile.root.children.first(where: { $0.name == entryName })
else { fatalError("entry \(entryName) not found in file \(filepath)") }

let stream = try oleFile.stream(infoEntry)

// Read version bytes from the encryption stream in little-endian order
let major: UInt16 = stream.read()
let minor: UInt16 = stream.read()

guard major == 4 && minor == 4
else { fatalError("unknown version: major \(major), minor \(minor)") }

// change position in the `stream`
reader.seek(toOffset: 8)
// get the rest of the data
let rawStreamData = reader.readDataToEnd()
```

You can refer to [source code of the CryptoOffice
library](https://github.com/CoreOffice/CryptoOffice/blob/3198d5e5add53fab66289a45f9f1760e360bac36/Sources/CryptoOffice/CryptoOfficeFile.swift#L28)
for a more detailed example.

## Requirements

**Apple Platforms**

- Xcode 11.0 or later
- Swift 5.1 or later

**Linux**

- Swift 5.1 or later

## Installation

### Swift Package Manager

[Swift Package Manager](https://swift.org/package-manager/) is a tool for
managing the distribution of Swift code. It’s integrated with the Swift build
system to automate the process of downloading, compiling, and linking
dependencies on all platforms.

Once you have your Swift package set up, adding `OLEKit` as a dependency is as
easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
  .package(
    url: "https://github.com/CoreOffice/OLEKit.git",
    .upToNextMinor(from: "0.2.0")
  )
]
```

If you're using OLEKit in an app built with Xcode, you can also add it as a direct
dependency [using Xcode's
GUI](https://developer.apple.com/documentation/xcode/adding_package_dependencies_to_your_app).

## Contributing

### Sponsorship

If this library saved you any amount of time or money, please consider [sponsoring
the work of its maintainer](https://github.com/sponsors/MaxDesiatov). While some of the
sponsorship tiers give you priority support or even consulting time, any amount is
appreciated and helps in maintaining the project.

### Coding Style

This project uses [SwiftFormat](https://github.com/nicklockwood/SwiftFormat)
and [SwiftLint](https://github.com/realm/SwiftLint) to
enforce formatting and coding style. We encourage you to run SwiftFormat within
a local clone of the repository in whatever way works best for you either
manually or automatically via an [Xcode
extension](https://github.com/nicklockwood/SwiftFormat#xcode-source-editor-extension),
[build phase](https://github.com/nicklockwood/SwiftFormat#xcode-build-phase) or
[git pre-commit
hook](https://github.com/nicklockwood/SwiftFormat#git-pre-commit-hook) etc.

To guarantee that these tools run before you commit your changes on macOS, you're encouraged
to run this once to set up the [pre-commit](https://pre-commit.com/) hook:

```
brew bundle # installs SwiftLint, SwiftFormat and pre-commit
pre-commit install # installs pre-commit hook to run checks before you commit
```

Refer to [the pre-commit documentation page](https://pre-commit.com/) for more details
and installation instructions for other platforms.

SwiftFormat and SwiftLint also run on CI for every PR and thus a CI build can
fail with incosistent formatting or style. We require CI builds to pass for all
PRs before merging.

### Code of Conduct

This project adheres to the [Contributor Covenant Code of
Conduct](https://github.com/CoreOffice/OLEKit/blob/master/CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code. Please report
unacceptable behavior to conduct@coreoffice.org.

## License

OLEKit is licensed under the Apache License, Version 2.0 (the "License");
you may not use this library except in compliance with the License.
See the
[LICENSE](https://github.com/CoreOffice/OLEKit/blob/master/LICENSE.md) file
for more info.

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

OLEKit is based on the code from the [olefile](https://github.com/decalage2/olefile)
library, which uses FreeBSD-style license, check out
[LICENSE-olefile](https://github.com/CoreOffice/OLEKit/blob/master/LICENSE-olefile)
for details.
