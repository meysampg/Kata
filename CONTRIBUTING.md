# Contributing to Kata

Thanks for helping. Bugs and ideas are welcome as [issues](https://github.com/meysampg/Kata/issues).

Before opening a pull request:

1. Run the kit tests: `swift test --package-path Packages/KataKit`
2. Make sure the app builds:
   `xcodebuild -project Kata.xcodeproj -scheme Kata -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -quiet build-for-testing`

Conventions:

- Pure logic belongs in `Packages/KataKit` (Foundation only) with tests; the app target holds UI and persistence.
- Do not commit changes to the signing team or bundle identifier. Set your own locally when running on a device.
- Content packs are validated with `swift test --package-path Packages/KataKit --filter ContentTests` (needs Java 21).
