#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"

index_store=""
for candidate in \
  ".build/out/v5" \
  ".build/debug/index/store" \
  ".build/arm64-apple-macosx/debug/index/store" \
  ".build/x86_64-apple-macosx/debug/index/store"; do
  if [[ -d "$candidate" ]]; then
    index_store="$candidate"
    break
  fi
done

if [[ -z "$index_store" ]]; then
  index_store="$(find .build -type d -path '*/debug/index/store' -print -quit)"
fi

if [[ -z "$index_store" || ! -d "$index_store" ]]; then
  print -u2 "Periphery index store not found. Run 'make build' first."
  exit 1
fi

periphery scan --skip-build --index-store-path "$index_store"
