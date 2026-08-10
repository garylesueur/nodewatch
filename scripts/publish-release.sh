#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
updates_dir="$project_dir/outputs/updates"
repository="${GITHUB_REPOSITORY:-garylesueur/nodewatch}"

if [[ -z "${NODEWATCH_VERSION:-}" ]]; then
  print -u2 "Missing required environment variable: NODEWATCH_VERSION"
  exit 1
fi

if [[ ! "$NODEWATCH_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$' ]]; then
  print -u2 "NODEWATCH_VERSION must be a semantic version such as 1.0.0 or 1.0.0-beta.1."
  exit 1
fi

tag="v$NODEWATCH_VERSION"
archive="$updates_dir/NodeWatch-${NODEWATCH_VERSION}.zip"
appcast="$updates_dir/appcast.xml"

[[ -f "$archive" ]] || { print -u2 "Release archive was not found: $archive"; exit 1; }
[[ -f "$appcast" ]] || { print -u2 "Sparkle appcast was not found: $appcast"; exit 1; }

if [[ -n "$(git -C "$project_dir" status --porcelain)" ]]; then
  print -u2 "Refusing to publish from a dirty working tree. Commit or stash source changes first."
  exit 1
fi

gh auth status --hostname github.com >/dev/null

assets=("$archive" "$appcast")
for delta in "$updates_dir"/*.delta(N); do
  assets+=("$delta")
done

gh release create "$tag" "${assets[@]}" \
  --repo "$repository" \
  --target "$(git -C "$project_dir" rev-parse HEAD)" \
  --title "NodeWatch $NODEWATCH_VERSION" \
  --generate-notes \
  --draft

print "Draft release created: https://github.com/$repository/releases/tag/$tag"
print "Review it in GitHub, then publish it to deploy the website and update feed."
