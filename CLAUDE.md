# 10PM Supper Club

SwiftUI iOS app (iPhone only) for four friends who go to late dinners and rank them. Home-screen name **10PM**; App Store name **10PM Supper Club**. Bundle ID `com.joelombardi.tenpmsupperclub`, team `V2RWATZXA2`, iOS 26+.

## Design
From the club's merch (black caps with cream embroidery): near-black backgrounds, cream type, Baskerville for names and numbers, wide-spaced capitals for labels, thin cream rules. Everything lives in `ViewsTheme.swift` (`Club` colors and fonts, `Wordmark`, `SpacedCaps`, `VolumeLabel`, `MemberBadge`, `RankNumeral`, `clubCard()`). Always dark (`.preferredColorScheme(.dark)`). Keep it sleek and uncluttered.

## How it works
- Dinners belong to **Volumes**, one per year: Volume I is 2025, II is 2026 (`Volume.of(date)`; nothing to start or store). Each member ranks the Volume's dinners they attended by **order only** (no scores), dragging in My List. The Club page orders dinners by **average position**; Members shows anyone's list next to the club's.
- Each member also scores a dinner on **Food, Drinks, Service, Cigability** (smoking a cig between courses) **and Vibe**, 1–10 in half points (`ScoreCategory`, kept on their `Review`). Scores show on the dinner's page and under dinners in Members; they never affect the club order.
- Data: `ModelsClub.swift` (models + `Standings`, no UI), `ServicesClubStore.swift` (`@Observable ClubStore`, optimistic edits saved through a `ClubBackend`).
- Backends: `CloudKitBackend` (real) and `DemoBackend` (in-memory sample club). Debug builds launched with `-demo YES` use the demo; `-tab N` and `-dinner <id>` open a tab or a dinner for screenshots.
- iCloud: container `iCloud.com.joelombardi.tenpmsupperclub`. The founder's private DB holds zone `SupperClub`, shared via a zone-wide `CKShare` (anyone with the link, read-write). Members read/write it in their shared DB. Record types: Member, Dinner, Ranking, Review, Photo (asset). Rankings are keyed by Volume id (`vol-2026`). Each member writes only their own Ranking/Review. Invites are accepted by `SceneDelegate` → `ShareInbox` → `CloudKitBackend.accept`. No push yet: refreshes on open, pull-to-refresh, and every 30 s.
- TestFlight builds use CloudKit's **Production** environment: deploy the schema in the CloudKit Console after it's created in Development.

## Layout
Flat `SupperClub/` folder (file-system synchronized group: new `.swift` files compile automatically; never hand-edit `project.pbxproj` to add files). Files prefixed by layer: `Models*`, `Services*`, `Views*`. `SupperClub-Info.plist` (repo root) adds `CKSharingSupported`; the rest of Info.plist is generated from build settings.

## Build & check
```bash
xcodebuild -project SupperClub.xcodeproj -scheme SupperClub -destination 'generic/platform=iOS Simulator' build
swiftc -parse-as-library -o /tmp/standings-check SupperClub/ModelsClub.swift scripts/standings-check.swift && /tmp/standings-check
```
App icon: `scripts/make-icon.swift` (header has the command).

## Conventions
- Small, focused diffs; build after changes. Uploading, submitting and releasing are outward-facing: confirm with Joe first.
