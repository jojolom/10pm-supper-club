#!/bin/bash
# Archive 10PM Supper Club and upload it to App Store Connect (lands in TestFlight).
# Uses the same App Store Connect API key as Guitar Man, outside the repo in
# ~/.appstoreconnect/neck-practice.env (ASC_KEY_ID, ASC_ISSUER_ID), with the key file at
# ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8. Never copy them into the repo.
# Export signing is manual (scripts/ExportOptions.plist): the "Apple Distribution" certificate
# in the login keychain and the "10PM Supper Club App Store" profile.
set -euo pipefail

cd "$(dirname "$0")/.."
source "$HOME/.appstoreconnect/neck-practice.env"
KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
AUTH=(-allowProvisioningUpdates
      -authenticationKeyPath "$KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")

# Build number: timestamp, always increasing. Version comes from MARKETING_VERSION in the project.
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
OUT="build/release-$BUILD_NUMBER"

xcodebuild archive \
  -project SupperClub.xcodeproj -scheme SupperClub -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/SupperClub.xcarchive" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" "${AUTH[@]}"

xcodebuild -exportArchive \
  -archivePath "$OUT/SupperClub.xcarchive" -exportPath "$OUT/export" \
  -exportOptionsPlist scripts/ExportOptions.plist "${AUTH[@]}"

echo "Uploaded build $BUILD_NUMBER. It appears in TestFlight after Apple finishes processing (~5-15 min)."
