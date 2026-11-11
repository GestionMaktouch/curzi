# Curzi

The old XE feel: a list of the currencies you use, tap any amount, type on the built-in
calculator keypad (`5×100÷7` works), and every other row updates at once. Drag the grip to reorder; long-press a row to pin it (every other row then
shows "1 PIN → rate") or delete it. Free; a one-time $2.99 "Support Curzi" purchase says thanks.

A second tab, **Growth**, is a compound-growth calculator: starting balance, annual return,
duration, a periodic addition compounded monthly, quarterly or yearly, and an inflation rate.
It shows the investment value, contributions, profit and the value in today's money, with a
chart (value, contributions and today's money by year) and a year-by-year table. Built on
[Exact](https://github.com/expo/exact), Expo's pre-alpha agent-native framework, so one
`app.contract` runs on the web, iOS and Android.

## Files

| File | What it is |
|---|---|
| `app.contract` | The view: the Convert tab (card list with grip, pin and menu; the keypad; the Add Currency sheet; Settings) and the Growth tab (form, chart, table) |
| `app.ts` | The data module: the rate feed, its offline cache, the expression evaluator, the growth projection, purchase delivery |
| `currencies.ts` | ISO 4217 codes with names and flags |
| `app.test.contract` | The tests (`bun exact.mjs test web`, `test ios`) |
| `store/catalog.json` | The store catalogue: the `support` non-consumable |
| `assets/` | The icon (`icon-1024.png`), launch mark (`launch.png`) and the logo's source (`logo.svg`) |
| `android/res/` | The Android adaptive launcher icon (`mipmap-*`), rendered from the same SVG |
| `app.json` | The manifest: name, bundle id, platforms, the catalogue |

## Setup

Exact has no packaged CLI; the app uses a source checkout at `../exact` (`EXACT2` overrides).

```sh
cd ..
git clone https://github.com/expo/exact.git && cd exact
git checkout 4756891b        # see "Pinned Exact" below
curl -fsSL https://bun.sh/install | BUN_INSTALL=~/.bun-1.4.2 bash -s bun-v1.4.2
~/.bun-1.4.2/bin/bun scripts/exact.mjs setup
```

Needs Rust (rustup), Xcode, and Google Chrome or Playwright's Chromium (setup installs it).

## Run

```sh
export PATH="$HOME/.bun-1.4.2/bin:$HOME/.cargo/bin:$PATH"
bun exact.mjs web            # dev loop in the browser, rebuilds on save
bun exact.mjs verify         # tests, screen checks, relaunch; clean means done
bun exact.mjs ios --run      # iOS Simulator (first build takes 10–15 min)
bun exact.mjs share          # an AppDrop link to try it on an iPhone
bun exact.mjs android        # builds the APK and installs it on the running emulator
bun exact.mjs test android   # the same tests on Android (ANDROID_SERIAL names the device)
```

### Android toolchain (installed 2026-11-10)

- JDK: Temurin 21 (`brew install --cask temurin@21`); `JAVA_HOME=$(/usr/libexec/java_home -v 21)`.
- SDK at `~/Library/Android/sdk` (where Exact looks): command-line tools, platform-tools,
  `platforms;android-37.2`, `build-tools;37.0.0` (Gradle also fetched 36.0.0),
  `ndk;29.0.14206865`, the emulator and `system-images;android-36;google_apis;arm64-v8a`.
- Emulator `curzi` (Pixel 8, API 36): `~/Library/Android/sdk/emulator/emulator -avd curzi`.
- Rust target `aarch64-linux-android` on both the pinned 1.97.0 toolchain and rustup's default,
  since Exact's check runs in the app folder.
- The Hermes bundle for Android from the Ibex release `hermes-vanilla-d412d3bd8512-v5`,
  installed with `bun ../exact/scripts/hermes-android.mjs install <tar.gz>`.
- The checkout carries local patches (`git -C ../exact diff`), to re-apply if the pin moves:
  - `host/android/app/build.gradle.kts` and its `AndroidManifest.xml` add
    `android:icon="${exactIcon}"` and pick up the app's `android/res` when it holds
    `mipmap-anydpi-v26/ic_launcher.xml`. Exact's shell has no icon support of its own yet.
  - `packages/purchases/android/Purchases.kt`: the `PurchasesUpdatedListener` property is moved
    above the `init` block that builds the BillingClient. Declared below it, the listener is still
    null at build time and Play Billing 9 throws "Please provide a valid listener", which crashed
    every real launch (the agent's substituted store never hit it).
- `gradle.lockfile` and `gradle-verification.xml` are the locked Gradle graph (Play Billing from
  the purchases module); regenerate with `bun exact.mjs android --write-locks` when it changes.

The folder must stay lowercase (`curzi`): Exact names the native crates after it.

## Rates

Mid-market rates against USD from the [Exchange Rate API](https://www.exchangerate-api.com)
open endpoint: free, no key, refreshed daily, attribution shown in Settings. The last answer
is cached at `app:/data/rates.json` so the app works offline and says so.

## Pinned Exact

Exact `main` after 2026-11-09 uses `UIArrangementViewController` (iOS 27.1 SDK). With Xcode
27.0 the iOS host does not compile, so the checkout is pinned at `4756891b`, the last commit
without it and the one Exact's own templates were built on. Move the pin once Xcode 27.1 is
installed: `git -C ../exact checkout main && git pull`, then `bun exact.mjs update`.

## Not done yet

- **Android.** Builds and passes its tests on the emulator, but Exact's Android host is early
  and has no Play Store packaging (signing, AAB) yet.
- **Store listing.** Icons, launch image, App Store Connect / Play Console products matching
  `store/catalog.json` (`support`, $2.99 tier).
