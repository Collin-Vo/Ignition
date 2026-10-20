#!/bin/zsh
#
# Builds Ignition for direct distribution (Developer ID), notarizes and staples
# the app, then wraps it in a signed + notarized installer pkg that installs
# Ignition.app into /Applications.
#
# One-time setup:
#   1. Install both "Developer ID Application" and "Developer ID Installer"
#      certificates for team JM7U494D23 (Xcode > Settings > Accounts > Manage Certificates).
#   2. Store notarization credentials in the keychain (use an app-specific password
#      from appleid.apple.com):
#        xcrun notarytool store-credentials ignition-notary \
#          --apple-id <you@example.com> --team-id JM7U494D23
#
# Usage:
#   scripts/release.zsh
#
# Environment overrides:
#   NOTARY_PROFILE   keychain profile for notarytool   (default: ignition-notary)
#   OUTPUT_DIR       where artifacts are written        (default: <repo>/.build/release)

set -euo pipefail

SCRIPT_DIR=${0:A:h}
REPO_ROOT=${SCRIPT_DIR:h}

PROJECT="$REPO_ROOT/Ignition/Ignition.xcodeproj"
SCHEME="Ignition"
CONFIGURATION="Release"
APP_NAME="Ignition"
TEAM_ID="JM7U494D23"
PKG_IDENTIFIER="de.collinvo.Ignition.pkg"
NOTARY_PROFILE=${NOTARY_PROFILE:-ignition-notary}
OUTPUT_DIR=${OUTPUT_DIR:-$REPO_ROOT/.build/release}

ARCHIVE_PATH="$OUTPUT_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$OUTPUT_DIR/export"
APP_PATH="$EXPORT_DIR/$APP_NAME.app"
PKG_ROOT="$OUTPUT_DIR/pkgroot"
WORK_DIR="$OUTPUT_DIR/work"

step() { print -P "\n%F{cyan}==>%f %B$1%b" }
fail() { print -P "%F{red}error:%f $1" >&2; exit 1 }

# Pipes xcodebuild output through xcbeautify when it's installed.
xcbeautify_or_cat() {
  if (( $+commands[xcbeautify] )); then xcbeautify; else cat; fi
}

# Prints the full name of the first valid identity of the given kind for TEAM_ID.
find_identity() {
  security find-identity -v \
    | grep -F "$1" \
    | grep -F "($TEAM_ID)" \
    | head -n 1 \
    | sed -E 's/^[[:space:]]*[0-9]+\) [0-9A-F]+ "(.*)"$/\1/' \
    || true
}

notarize() {
  local file=$1
  step "Notarizing ${file:t}"
  local result="$WORK_DIR/notary-${file:t}.plist"
  xcrun notarytool submit "$file" --keychain-profile "$NOTARY_PROFILE" --wait --output-format plist > "$result"
  local submission_status submission_id
  submission_status=$(/usr/libexec/PlistBuddy -c "Print :status" "$result")
  submission_id=$(/usr/libexec/PlistBuddy -c "Print :id" "$result")
  if [[ $submission_status != "Accepted" ]]; then
    xcrun notarytool log "$submission_id" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    fail "Notarization of ${file:t} finished with status '$submission_status' (submission $submission_id)"
  fi
  print "Accepted (submission $submission_id)"
}

# --- Preflight -----------------------------------------------------------------

step "Checking signing identities and notary credentials"
APP_IDENTITY=$(find_identity "Developer ID Application")
INSTALLER_IDENTITY=$(find_identity "Developer ID Installer")
[[ -n $APP_IDENTITY ]] || fail "No 'Developer ID Application' certificate for team $TEAM_ID in the keychain."
[[ -n $INSTALLER_IDENTITY ]] || fail "No 'Developer ID Installer' certificate for team $TEAM_ID in the keychain."
print "App:       $APP_IDENTITY"
print "Installer: $INSTALLER_IDENTITY"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" > /dev/null 2>&1 \
  || fail "Notary profile '$NOTARY_PROFILE' not found or invalid. See setup notes at the top of this script."

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR" "$WORK_DIR"

# --- Build and export the app ----------------------------------------------------

step "Archiving $SCHEME ($CONFIGURATION)"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  | xcbeautify_or_cat

step "Exporting with Developer ID signing"
EXPORT_OPTIONS="$WORK_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>teamID</key>
  <string>$TEAM_ID</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>destination</key>
  <string>export</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates \
  | xcbeautify_or_cat

[[ -d $APP_PATH ]] || fail "Export did not produce $APP_PATH"

step "Verifying app signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv --verbose=2 "$APP_PATH" 2>&1 | grep -E "Authority=Developer ID Application|flags=.*runtime" \
  || fail "App is not signed with Developer ID and hardened runtime."

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist")
print "Version $VERSION ($BUILD)"

# --- Notarize and staple the app -------------------------------------------------

APP_ZIP="$WORK_DIR/$APP_NAME.zip"
ditto -c -k --keepParent "$APP_PATH" "$APP_ZIP"
notarize "$APP_ZIP"

step "Stapling app"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH"

# Distributable zip of the stapled app, for anyone who prefers it over the pkg.
ditto -c -k --keepParent "$APP_PATH" "$OUTPUT_DIR/$APP_NAME-$VERSION.zip"

# --- Build the installer pkg -----------------------------------------------------

step "Building installer package"
mkdir -p "$PKG_ROOT"
ditto "$APP_PATH" "$PKG_ROOT/$APP_NAME.app"

# Always install to /Applications, even if another copy of the bundle exists elsewhere.
COMPONENT_PLIST="$WORK_DIR/component.plist"
pkgbuild --analyze --root "$PKG_ROOT" "$COMPONENT_PLIST"
plutil -replace 0.BundleIsRelocatable -bool NO "$COMPONENT_PLIST"

COMPONENT_PKG="$WORK_DIR/$APP_NAME-component.pkg"
pkgbuild \
  --root "$PKG_ROOT" \
  --component-plist "$COMPONENT_PLIST" \
  --install-location /Applications \
  --identifier "$PKG_IDENTIFIER" \
  --version "$VERSION" \
  "$COMPONENT_PKG"

DISTRIBUTION="$WORK_DIR/distribution.xml"
productbuild --synthesize --package "$COMPONENT_PKG" "$DISTRIBUTION"

PKG_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION.pkg"
productbuild \
  --distribution "$DISTRIBUTION" \
  --package-path "$WORK_DIR" \
  --sign "$INSTALLER_IDENTITY" \
  --timestamp \
  "$PKG_PATH"

pkgutil --check-signature "$PKG_PATH"

# --- Notarize and staple the pkg -------------------------------------------------

notarize "$PKG_PATH"

step "Stapling pkg"
xcrun stapler staple "$PKG_PATH"
xcrun stapler validate "$PKG_PATH"
spctl --assess --type install --verbose=2 "$PKG_PATH"

rm -rf "$WORK_DIR" "$PKG_ROOT"

step "Done"
print "App:     $APP_PATH"
print "Zip:     $OUTPUT_DIR/$APP_NAME-$VERSION.zip"
print "Pkg:     $PKG_PATH"
print "Archive: $ARCHIVE_PATH"
