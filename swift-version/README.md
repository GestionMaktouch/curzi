# Curzi, the Swift version

A SwiftUI + StoreKit 2 translation of the Exact app one folder up, feature for feature, written
to compare code length. It type-checks against the iOS 17 simulator SDK
(`xcrun swiftc -typecheck -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -target arm64-apple-ios17.0-simulator -parse-as-library Curzi/*.swift`)
but has no Xcode project, icon, or tests: to run it, make an iOS App project in Xcode and drop
`Curzi/` in.

## What it covers

Card list of currencies with monospaced amounts; drag to reorder (`List.onMove`, a long press
on iOS); long-press menu with Pin and Delete; pinning moves the currency first and shows
`1 PIN → rate` under every other row; the calculator keypad with `5×100÷7` evaluation, first key
replaces, `=` works it out; the Add Currency sheet with search; Settings with the `support`
purchase, Restore, Show decimals, and the relative "Rates last updated"; the rate feed with an
offline cache; persistence via `@AppStorage`.

## Line counts

Code lines are non-blank lines that are not comments.

| | Exact | Swift |
|---|---|---|
| View | `app.contract` 325 | `ContentView` 81 + `Keypad` 45 + `AddCurrencyView` 41 + `SettingsView` 78 + `CurziApp` 12 = 257 |
| Logic and data | `app.ts` 121 | `AppModel` 90 + `Models` 86 + `RatesService` 36 = 212 |
| **App total** | **446** | **469** |
| Currency table | `currencies.ts` 165 | `Currencies.swift` 168 |
| Tests | `app.test.contract` 145 | none |

Roughly the same size. Where they differ:

- Exact's view is longer because layout is spelled out as CSS attributes on every node, and
  because it writes what SwiftUI gives for free (`List`, `.contextMenu`, `.searchable`,
  `ContentUnavailableView`).
- Exact's logic is shorter because resources, mutations, persistence (`persist`) and purchase
  delivery are declarations, where Swift has `ObservableObject`, an `actor`, `Codable`
  wrappers and the StoreKit 2 transaction loop.
- The Exact version also runs on the web and macOS from the same source and comes with 13
  tests that drive it on both the browser and the simulator. The Swift version runs on iOS,
  and testing it would mean XCTest plus UI tests.
- Exact's purchase delivery is one loop in `app.ts`; StoreKit 2's is `Store` in
  `SettingsView.swift`, about the same length.
