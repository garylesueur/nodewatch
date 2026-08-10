#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
output_dir="$project_dir/outputs"
updates_dir="$output_dir/updates"
app_dir="$output_dir/NodeWatch.app"

export NODEWATCH_BUNDLE_ID="${NODEWATCH_BUNDLE_ID:-dev.gaz.nodewatch}"
export SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://nodewatch.gaz.dev/appcast.xml}"
export SPARKLE_DOWNLOAD_URL_PREFIX="${SPARKLE_DOWNLOAD_URL_PREFIX:-https://github.com/garylesueur/nodewatch/releases/download/v${NODEWATCH_VERSION:-}/}"

required=(
  NODEWATCH_VERSION
  NODEWATCH_BUILD_NUMBER
  NODEWATCH_SIGNING_IDENTITY
  SPARKLE_PUBLIC_KEY
  NOTARYTOOL_PROFILE
)

for name in "${required[@]}"; do
  if [[ -z "${(P)name:-}" ]]; then
    print -u2 "Missing required environment variable: $name"
    exit 1
  fi
done

if [[ ! "$NODEWATCH_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$' ]]; then
  print -u2 "NODEWATCH_VERSION must be a semantic version such as 1.0.0 or 1.0.0-beta.1."
  exit 1
fi

if [[ "$NODEWATCH_SIGNING_IDENTITY" == "-" ]]; then
  print -u2 "A Developer ID Application identity is required for a release."
  exit 1
fi

if [[ "$SPARKLE_FEED_URL" != https://* || "$SPARKLE_DOWNLOAD_URL_PREFIX" != https://* ]]; then
  print -u2 "Sparkle feed and download URLs must use HTTPS."
  exit 1
fi

"$project_dir/scripts/build-app.sh"

mkdir -p "$updates_dir"
archive="$updates_dir/NodeWatch-${NODEWATCH_VERSION}.zip"
rm -f "$archive"
/usr/bin/ditto -c -k --keepParent "$app_dir" "$archive"

xcrun notarytool submit "$archive" \
  --keychain-profile "$NOTARYTOOL_PROFILE" \
  --wait
xcrun stapler staple "$app_dir"
xcrun stapler validate "$app_dir"

rm -f "$archive"
/usr/bin/ditto -c -k --keepParent "$app_dir" "$archive"

generate_appcast="$project_dir/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
[[ -x "$generate_appcast" ]] || { print -u2 "Sparkle's generate_appcast tool was not found."; exit 1; }
"$generate_appcast" \
  --account "${SPARKLE_KEY_ACCOUNT:-nodewatch}" \
  --download-url-prefix "$SPARKLE_DOWNLOAD_URL_PREFIX" \
  --link "https://nodewatch.gaz.dev/" \
  "$updates_dir"

spctl --assess --type execute --verbose=2 "$app_dir"
print "Release ready in $updates_dir"
