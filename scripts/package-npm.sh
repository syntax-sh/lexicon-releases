#!/usr/bin/env bash
# Build the @syntax-sh npm packages from a lexicon release's artifacts.
#
# Usage: scripts/package-npm.sh <version> <artifacts-dir> [out-dir]
#
# <artifacts-dir> must contain lexicon-<triple>.tar.gz and the matching
# .sha256 files for every target below. Produces the same layout cargo-npm
# generates in the (private) source repo: one platform package per target
# with the binary bundled (os/cpu constrained, no install scripts) plus a
# main @syntax-sh/lexicon package whose Node shim execs the right binary.
#
# This lives here — in the public releases repo — because npm provenance
# attestations require the publishing workflow (and the package.json
# `repository` field) to reference a public repo.
set -euo pipefail

VERSION=${1:?usage: package-npm.sh <version> <artifacts-dir> [out-dir]}
ARTIFACTS=${2:?usage: package-npm.sh <version> <artifacts-dir> [out-dir]}
OUT=${3:-npm}

SCOPE="@syntax-sh"
REPO_URL="git+https://github.com/syntax-sh/lexicon-releases.git"
HOMEPAGE="https://syntax.sh/lexicon"
DESCRIPTION="CLI that analyzes a repo's package manager configs to identify used libraries and builds a shared, indexed cache of vendor documentation for coding agents"

# triple -> npm platform suffix / os / cpu / binary name
platforms=(
  "aarch64-apple-darwin|darwin-arm64|darwin|arm64|lexicon"
  "x86_64-apple-darwin|darwin-x64|darwin|x64|lexicon"
  "x86_64-unknown-linux-gnu|linux-x64|linux|x64|lexicon"
  "x86_64-pc-windows-msvc|win32-x64|win32|x64|lexicon.exe"
)

sha256_check() {
  local file=$1 sumfile=$2
  local want got
  want=$(awk '{print $1}' "$sumfile")
  if command -v sha256sum >/dev/null; then
    got=$(sha256sum "$file" | awk '{print $1}')
  else
    got=$(shasum -a 256 "$file" | awk '{print $1}')
  fi
  [[ $want == "$got" ]] || { echo "checksum mismatch for $file" >&2; exit 1; }
}

rm -rf "$OUT"
mkdir -p "$OUT/$SCOPE"

optional_deps=""
for entry in "${platforms[@]}"; do
  IFS='|' read -r triple suffix os cpu bin <<<"$entry"
  archive="$ARTIFACTS/lexicon-$triple.tar.gz"
  sha256_check "$archive" "$archive.sha256"

  pkgdir="$OUT/$SCOPE/lexicon-$suffix"
  mkdir -p "$pkgdir"
  tar -xzf "$archive" -C "$pkgdir" --strip-components=1
  test -f "$pkgdir/$bin" || { echo "missing $bin in $archive" >&2; exit 1; }
  rm -f "$pkgdir/README.md"

  cat >"$pkgdir/package.json" <<JSON
{
  "name": "$SCOPE/lexicon-$suffix",
  "version": "$VERSION",
  "homepage": "$HOMEPAGE",
  "license": "SEE LICENSE IN LICENSE",
  "repository": {
    "type": "git",
    "url": "$REPO_URL"
  },
  "os": [
    "$os"
  ],
  "cpu": [
    "$cpu"
  ]
}
JSON
  optional_deps+="    \"$SCOPE/lexicon-$suffix\": \"$VERSION\",\n"
done

main="$OUT/$SCOPE/lexicon"
mkdir -p "$main/bin"
# Reuse LICENSE/README shipped inside the first archive for the main package.
tar -xzf "$ARTIFACTS/lexicon-aarch64-apple-darwin.tar.gz" -C "$main" --strip-components=1 --exclude '*/lexicon'
rm -f "$main/lexicon"

cat >"$main/bin/lexicon.js" <<'JS'
#!/usr/bin/env node
'use strict'

const PLATFORMS = {
  darwin: {
    arm64: '@syntax-sh/lexicon-darwin-arm64/lexicon',
    x64: '@syntax-sh/lexicon-darwin-x64/lexicon',
  },
  linux: {
    x64: '@syntax-sh/lexicon-linux-x64/lexicon',
  },
  win32: {
    x64: '@syntax-sh/lexicon-win32-x64/lexicon.exe',
  },
}

const binPath = PLATFORMS[process.platform]?.[process.arch]

if (!binPath) {
  console.error(`Unsupported platform: ${process.platform} ${process.arch}`)
  process.exit(1)
}

const bin = require.resolve(binPath)
const result = require('child_process').spawnSync(bin, process.argv.slice(2), { stdio: 'inherit' })
if (result.error) {
  throw result.error
}
process.exitCode = result.status ?? 1
JS

cat >"$main/package.json" <<JSON
{
  "name": "$SCOPE/lexicon",
  "version": "$VERSION",
  "description": "$DESCRIPTION",
  "keywords": [
    "documentation",
    "cli",
    "cache",
    "vendor-docs",
    "coding-agents"
  ],
  "homepage": "$HOMEPAGE",
  "license": "SEE LICENSE IN LICENSE",
  "repository": {
    "type": "git",
    "url": "$REPO_URL"
  },
  "bin": {
    "lexicon": "bin/lexicon.js"
  },
  "engines": {
    "node": ">=14"
  },
  "optionalDependencies": {
$(printf '%b' "$optional_deps" | sed '$ s/,$//')
  }
}
JSON

echo "Generated npm packages in $OUT"
