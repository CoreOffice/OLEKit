# 0.2.0 (29 September 2020)

This a bugfix release that breaks API compatibility. It fixes issues with reading OLE mini-streams,
and hierarchies of directory entries. The `DataReader` API was updated to use `Int` instead of
`UInt64` to avoid potential overflow issues. Corresponding `read` methods on `DataReader` can
now trigger a precondition assertion if you try to read after reaching an end-of-stream position.
To prevent this, you should check the value of a new `totalBytes` property on `DataReader`.

Additionally, basic API documentation is now generated with
[`swift-doc`](https://github.com/SwiftDocOrg/swift-doc) and is now [hosted with GitHub
Pages](https://coreoffice.github.io/OLEKit/).

**Breaking changes:**

- Add preconditions to `DataStream`, tweak seek API ([#3](https://github.com/CoreOffice/OLEKit/pull/3)) via [@MaxDesiatov](https://github.com/MaxDesiatov)

**Closed issues:**

- [Bug] Storage & Stream Structure is Different while testing .hwp file ([#6](https://github.com/CoreOffice/OLEKit/issues/6))
- [Bug] get wrong stream position while get "FileHeader" stream in ".hwp" file ([#1](https://github.com/CoreOffice/OLEKit/issues/1))

**Merged pull requests:**

- Fix incorrectly built entries hierarchy ([#7](https://github.com/CoreOffice/OLEKit/pull/7)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Fix miniStream iteration bug, add HWP test ([#5](https://github.com/CoreOffice/OLEKit/pull/5)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Generate and publish documentation with `swift-doc` ([#4](https://github.com/CoreOffice/OLEKit/pull/4)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Fix branch name in `main.yml`, test on new Xcode ([#2](https://github.com/CoreOffice/OLEKit/pull/2)) via [@MaxDesiatov](https://github.com/MaxDesiatov)

# 0.1.0 (31 May 2020)

Initial release of OLEKit that provides basic features for [the CryptoOffice
library](https://github.com/CoreOffice/CryptoOffice/).