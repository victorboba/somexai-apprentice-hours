# Apprentice Hours

The hour book for a registered trade apprenticeship. It tracks hours by work process against the minimums your standards require, tracks sign-offs, and produces a PDF for the sponsor. For apprentices in the trades.

One of a set of niche iPhone apps built from a shared SwiftUI template. It was never released on the App Store; the code is here for anyone to use. The template is [somexai-ios-template](https://github.com/victorboba/somexai-ios-template) and the collection is [somexai-ios-apps](https://github.com/victorboba/somexai-ios-apps).

## What it does

- **Program**: name, apprentice number, trade, sponsor, program number, required on-the-job and classroom hours, hours already credited, and how often the sponsor wants a report.
- **Work processes**: a starter list for eight trades, each with its own required minimum, reorderable, and removable without losing the hours logged against it. The starter names are a convenience and are meant to be edited.
- **Progress**: a ring for hours of the total, recent pace and weeks left at that pace, this period's hours, an unsigned-hours warning, and the four processes furthest behind.
- **Hours**: one tap on a recent process plus the hours. Grouped by week with the week's total in the header.
- **Classes**: related instruction counted separately, grouped by month, against its own requirement.
- **Report**: pick a period, see its totals and breakdown, mark the period signed with who signed and when, then export.
- **Export**: a sponsor PDF with a signature block, plus CSVs for hours, classes and the work-process summary.
- A Home Screen widget, a Siri App Shortcut ("Log hours in Apprentice Hours"), and a step-by-step How do I use guide.

## The boundary

The app does not know your program. Required hours, work processes and their minimums differ by state, sponsor and trade, so the apprentice types all of them in. `AppConfig.disclaimer` says the app adds up what you log against your own numbers and is not your sponsor, your joint apprenticeship committee or your state apprenticeship agency. It appears on Progress, in the setup form, on the Report tab, in Settings and at the foot of every export.

## Privacy

All data stays on the device in SwiftData. There is no account, no analytics and no network code, and `AppConfig.iCloudSyncEnabled` is `false`. CSV and PDF export happen only when you choose to share a file.

## Build and run

Requirements: Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), and iOS 17+.

```bash
xcodegen generate
open ApprenticeHours.xcodeproj
```

Pick the `ApprenticeHours` scheme and an iPhone simulator, then Run.

Tests:

```bash
xcodebuild -scheme ApprenticeHours -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test
```

Paywall: the app has a hard paywall (annual subscription or lifetime purchase). Running from Xcode uses the bundled `Products.storekit` file, so purchases are simulated and free. Debug builds can also skip it with the `-unlock` launch argument or the Debug switch in Settings. Debug builds also accept the launch arguments `-sampleData`, `-resetData`, `-skipOnboarding`, `-mockPrices` and `-uiTesting`; Settings has a Debug section with sample data.

To run on your own device or ship it: set your team in `project.yml` (`DEVELOPMENT_TEAM`), change the `com.example` bundle ID prefix in `project.yml`, both `.entitlements` files and `Products.storekit`, and update `supportEmail`, `privacyPolicyURL` and `appStoreID` in `Shared/AppConfig.swift`.

## Project layout

- `ApprenticeHours/App/`: app entry point and the root view that gates onboarding, paywall and the app.
- `ApprenticeHours/Core/`: StoreKit entitlement, CSV and PDF export, App Intents, review prompt, widget sync, debug flags and sample data.
- `ApprenticeHours/Features/`: the screens, including onboarding, paywall, settings and the How do I use guide.
- `ApprenticeHours/Models/`: the SwiftData models and the calculation code. Models are `Program` and `WorkEntry`; pure calculation lives in `HoursMath`.
- `ApprenticeHours/StoreKit/Products.storekit`: local StoreKit configuration.
- `ApprenticeHoursWidget/`: the Home Screen widget, fed by a snapshot in the App Group.
- `ApprenticeHoursTests/` and `ApprenticeHoursUITests/`: unit and UI tests.
- `Shared/AppConfig.swift`: everything that changes per app (name, copy, onboarding, paywall benefits, How-to steps, disclaimer, product IDs, links).
- `scripts/`: icon and screenshot helpers. `docs/` has notes on capabilities such as iCloud and App Groups.

## Technical notes

- `WorkEntry` snapshots the work process name, so renaming or removing a process never rewrites hours already signed for. Removing archives rather than deletes.
- `HoursMath.uncategorised` reports hours logged against archived processes, so nothing silently drops out of a total.
- Periods align to the calendar year, so quarters land where a sponsor expects them.
- `weeklyPace` averages only weeks that had hours, so a layoff does not halve the projection.
- `HoursMath` has no SwiftData dependency and is unit-tested directly.

## License

MIT. See [LICENSE](LICENSE).
