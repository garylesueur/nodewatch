#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
output_dir="$project_dir/outputs"
app_dir="$output_dir/NodeWatch.app"
contents_dir="$app_dir/Contents"
binary_dir="$contents_dir/MacOS"
frameworks_dir="$contents_dir/Frameworks"
resources_dir="$contents_dir/Resources"
module_cache="$project_dir/work/clang-module-cache"
package_cache="$project_dir/work/swiftpm-cache"
app_icon="$project_dir/Assets/NodeWatch.icns"

version="${NODEWATCH_VERSION:-0.1.0}"
build_number="${NODEWATCH_BUILD_NUMBER:-1}"
bundle_id="${NODEWATCH_BUNDLE_ID:-com.nodewatch.app}"
signing_identity="${NODEWATCH_SIGNING_IDENTITY:--}"
feed_url="${SPARKLE_FEED_URL:-}"
public_key="${SPARKLE_PUBLIC_KEY:-}"
architectures=(${=NODEWATCH_ARCHS:-arm64 x86_64})

if [[ ( -n "$feed_url" && -z "$public_key" ) || ( -z "$feed_url" && -n "$public_key" ) ]]; then
  print -u2 "SPARKLE_FEED_URL and SPARKLE_PUBLIC_KEY must either both be set or both be omitted."
  exit 1
fi

if [[ "$build_number" != <-> ]] || (( build_number < 1 )); then
  print -u2 "NODEWATCH_BUILD_NUMBER must be a positive integer."
  exit 1
fi

arch_flags=()
for architecture in "${architectures[@]}"; do
  arch_flags+=(--arch "$architecture")
done

cd "$project_dir"
mkdir -p "$module_cache" "$package_cache"
export CLANG_MODULE_CACHE_PATH="$module_cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$module_cache"

swift build \
  -c release \
  --disable-sandbox \
  -Xswiftc -disable-sandbox \
  --cache-path "$package_cache" \
  "${arch_flags[@]}"

build_dir="$(swift build \
  -c release \
  --disable-sandbox \
  -Xswiftc -disable-sandbox \
  --cache-path "$package_cache" \
  "${arch_flags[@]}" \
  --show-bin-path)"

[[ -x "$build_dir/NodeWatch" ]] || { print -u2 "NodeWatch binary was not produced."; exit 1; }
[[ -d "$build_dir/Sparkle.framework" ]] || { print -u2 "Sparkle.framework was not produced."; exit 1; }
[[ -f "$app_icon" ]] || { print -u2 "NodeWatch app icon was not found."; exit 1; }
[[ "$app_dir" == "$project_dir/outputs/NodeWatch.app" ]] || {
  print -u2 "Refusing to replace an unexpected app path: $app_dir"
  exit 1
}

rm -rf "$app_dir"
mkdir -p "$binary_dir" "$frameworks_dir" "$resources_dir"
cp "$build_dir/NodeWatch" "$binary_dir/NodeWatch"
cp "$app_icon" "$resources_dir/NodeWatch.icns"
/usr/bin/ditto "$build_dir/Sparkle.framework" "$frameworks_dir/Sparkle.framework"

# Swift Package Manager links binary frameworks through @rpath but its executable
# build product only searches beside itself. An app bundle keeps frameworks in
# Contents/Frameworks, so add the standard app-relative runtime search path before
# signing the executable.
app_framework_rpath="@executable_path/../Frameworks"
/usr/bin/install_name_tool -add_rpath "$app_framework_rpath" "$binary_dir/NodeWatch"

if ! /usr/bin/otool -l "$binary_dir/NodeWatch" | /usr/bin/awk -v expected="$app_framework_rpath" '
  $1 == "cmd" && $2 == "LC_RPATH" { in_rpath = 1; next }
  in_rpath && $1 == "path" { if ($2 == expected) found = 1; in_rpath = 0 }
  END { exit(found ? 0 : 1) }
'; then
  print -u2 "NodeWatch is missing the app framework runtime search path."
  exit 1
fi

linked_dependencies=("${(@f)$(/usr/bin/otool -L "$binary_dir/NodeWatch" | /usr/bin/awk 'NR > 1 { print $1 }')}" )
for dependency in "${linked_dependencies[@]}"; do
  if [[ "$dependency" == @rpath/* ]]; then
    bundled_dependency="$frameworks_dir/${dependency#@rpath/}"
    [[ -e "$bundled_dependency" ]] || {
      print -u2 "Bundled dependency is missing: $bundled_dependency"
      exit 1
    }
  fi
done

info_plist="$contents_dir/Info.plist"
plutil -create xml1 "$info_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleName string NodeWatch" "$info_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string NodeWatch" "$info_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $bundle_id" "$info_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string NodeWatch" "$info_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string NodeWatch" "$info_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$info_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $version" "$info_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $build_number" "$info_plist"
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 14.0" "$info_plist"
/usr/libexec/PlistBuddy -c "Add :LSApplicationCategoryType string public.app-category.developer-tools" "$info_plist"
/usr/libexec/PlistBuddy -c "Add :NSHighResolutionCapable bool true" "$info_plist"
/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$info_plist"
/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" "$info_plist"

if [[ -n "$feed_url" ]]; then
  /usr/libexec/PlistBuddy -c "Add :SUFeedURL string $feed_url" "$info_plist"
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $public_key" "$info_plist"
  /usr/libexec/PlistBuddy -c "Add :SUVerifyUpdateBeforeExtraction bool true" "$info_plist"
  /usr/libexec/PlistBuddy -c "Add :SURequireSignedFeed bool true" "$info_plist"
fi

xattr -cr "$app_dir"

sparkle="$frameworks_dir/Sparkle.framework/Versions/B"
if [[ "$signing_identity" == "-" ]]; then
  codesign --force --deep --sign - "$app_dir"
else
  sign=(codesign --force --sign "$signing_identity" --options runtime --timestamp)
  "${sign[@]}" "$sparkle/XPCServices/Installer.xpc"
  "${sign[@]}" --preserve-metadata=entitlements "$sparkle/XPCServices/Downloader.xpc"
  "${sign[@]}" "$sparkle/Autoupdate"
  "${sign[@]}" "$sparkle/Updater.app"
  "${sign[@]}" "$frameworks_dir/Sparkle.framework"
  "${sign[@]}" "$app_dir"
fi

codesign --verify --deep --strict --verbose=2 "$app_dir"
print "$app_dir"
