# 10PM Supper Club

SwiftUI iOS app (iPhone only) for four friends who go to late dinners and rank them; anyone else with the app can look, as a guest. Home-screen name **10PM**; App Store name **10PM Supper Club**. Bundle ID `com.joelombardi.tenpmsupperclub`, team `V2RWATZXA2`, iOS 26+.

## Design
From the club's merch (black caps with cream embroidery): near-black backgrounds, cream type, Baskerville for names and numbers, wide-spaced capitals for labels, thin cream rules. Everything lives in `ViewsTheme.swift` (`Club` colors and fonts, `Wordmark`, `SpacedCaps`, `VolumeLabel`, `MemberBadge`, `RankNumeral`, `clubCard()`). Always dark (`.preferredColorScheme(.dark)`). Keep it sleek and uncluttered.

## How it works
- Dinners belong to **Volumes**, one per year: Volume I is 2025, II is 2026 (`Volume.of(date)`; nothing to start or store). Each member ranks the Volume's dinners they attended by **order only** (no scores), dragging in My List. The Club page orders dinners by **average position**; Members shows anyone's list next to the club's.
- **Members vs guests**: the club (`ClubInfo`: founder + everyone they've let in) adds, ranks, scores and writes notes. Anyone else with the app is a guest: they see everything (no iCloud needed), and with iCloud can score (no notes) any dinner the club has ranked or scored (`clubHasRated`). Guests' scores show as a separate Guests column (average) on the dinner's page, never in the club's scores or order. Joining: "I'm in the Club" + a name creates a Member record = a request; the founder taps Let In / Not Now in Members. Invite = the App Store page (`MembersView.inviteURL`). The app filters to members' records (dinners by `addedBy`, rankings, reviews), and gates every edit on `isMember`.
- Each member also scores a dinner on **Food, Drinks, Service, Cigability** (smoking a cig between courses) **and Vibe**, 1–10 in half points (`ScoreCategory`, kept on their `Review`). Scores show on the dinner's page and under dinners in Members; they never affect the club order.
- Data: `ModelsClub.swift` (models + `Standings`, no UI), `ServicesClubStore.swift` (`@Observable ClubStore`, optimistic edits saved through a `ClubBackend`).
- Backends: `CloudKitBackend` (real) and `DemoBackend` (in-memory sample club). Debug builds launched with `-demo YES` use the demo (as Joe, the founder; add `-guest YES` to be a guest); `-tab N` and `-dinner <id>` open a tab or a dinner for screenshots.
- iCloud: container `iCloud.com.joelombardi.tenpmsupperclub`, **public database** (default zone). Record types: Club (one, `club`), Member, Dinner, Ranking, Review, GuestReview, Photo (asset). A load queries every record of each type. Rankings are keyed by Volume id (`vol-2026`). iCloud enforces: everyone writes only their own Club/Member/Ranking/Review/GuestReview; Dinner and Photo are writable by any iCloud user (so any member can edit), and only the app keeps guests out. Public-DB queries lag new records by a few seconds, so `ClubStore` re-applies its own edits from the last minute over each load. No push yet: refreshes on open, pull-to-refresh, and every 30 s.
- TestFlight builds use CloudKit's **Production** environment: deploy the schema in the CloudKit Console after it's created in Development.

## Layout
Flat `SupperClub/` folder (file-system synchronized group: new `.swift` files compile automatically; never hand-edit `project.pbxproj` to add files). Files prefixed by layer: `Models*`, `Services*`, `Views*`. `SupperClub-Info.plist` (repo root) is empty; Info.plist is generated from build settings.

## Build & check
```bash
xcodebuild -project SupperClub.xcodeproj -scheme SupperClub -destination 'generic/platform=iOS Simulator' build
swiftc -parse-as-library -o /tmp/standings-check SupperClub/ModelsClub.swift scripts/standings-check.swift && /tmp/standings-check
```
App icon: `scripts/make-icon.swift` (header has the command).

## Release
- App Store Connect app id 6823010763. TestFlight groups: "Club Internal" (Joe, every build) and "Supper Club" (external, public link https://testflight.apple.com/join/qnFPRnue, up to 10).
- `docs/index.html`: Support & Privacy Policy page, served by GitHub Pages at https://jojolom.github.io/10pm-supper-club/ (the listing's support and privacy URL; `Support` in `ServicesSupport.swift` links to it and drafts report emails to jojolom.lombardi@icloud.com). Keep it accurate when the app's data handling changes. The repo is public for this, so never commit keys or tokens.
- App Store listing (US only, free, Food & Drink) is filled through the App Store Connect API with `~/Developer/Guitar Man/scripts/asc.py`. App Privacy answers can only be set on the website.
- Upload to TestFlight with `scripts/upload-testflight.sh` (archives, signs, uploads; build number = timestamp). Same App Store Connect API key as Guitar Man, in `~/.appstoreconnect/` — never copy it into the repo or print it.
- Export signing is manual (`scripts/ExportOptions.plist`, `iCloudContainerEnvironment` = Production): the "Apple Distribution" certificate in Joe's login keychain and an App Store profile named "10PM Supper Club App Store" (create with `python3 ~/Developer/Guitar\ Man/scripts/asc.py POST /v1/profiles ...`).
- The bundle ID is registered (with iCloud) but the iCloud container must be created by a signed-in Xcode or the developer website: the API can't. The CloudKit schema is `scripts/schema.ckdb`. Load it into Development with `xcrun cktool save-token --type management` (once; Joe pastes a management token from the CloudKit Console) then `xcrun cktool import-schema --team-id V2RWATZXA2 --container-id iCloud.com.joelombardi.tenpmsupperclub --environment development --file scripts/schema.ckdb`, then deploy Development to Production in the CloudKit Console, before testers use a build. Keep it in step with `CloudKitBackend`.

## Conventions
- Small, focused diffs; build after changes. Remote: public repo github.com/jojolom/10pm-supper-club (`main`). Uploading, submitting and releasing are outward-facing: confirm with Joe first.
