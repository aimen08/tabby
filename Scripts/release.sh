#!/bin/bash
# Builds, signs and publishes a release, then points Sparkle and Homebrew at it.
#   ./Scripts/release.sh                     # bump the patch of the latest tag
#   ./Scripts/release.sh 1.2.0 "What's new"  # explicit version and notes
#
# Releases are cut locally, not in CI: the app must be signed with the stable
# certificate in .signing-identity, or every update would cost users their
# Accessibility permission.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="aimen08/tabby"
KEY=".sparkle-keys/private_key"
SIGN_UPDATE=".build/artifacts/sparkle/Sparkle/bin/sign_update"

gh auth status >/dev/null 2>&1 || { echo "✗ gh is not authenticated (gh auth login)"; exit 1; }
[ -f "$KEY" ] || { echo "✗ Missing $KEY (Sparkle private key)"; exit 1; }
[ -f .signing-identity ] || { echo "✗ Missing .signing-identity"; exit 1; }
[ "$(git branch --show-current)" = main ] || { echo "✗ Release from main"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "✗ Commit or stash your changes first"; exit 1; }

git fetch --tags --quiet origin
if [ -n "${1:-}" ]; then
    VERSION="$1"
else
    LAST="$(git tag --list 'v*' --sort=-v:refname | head -1)"
    LAST="${LAST#v}"
    if [ -z "$LAST" ]; then VERSION="1.0.0"
    else VERSION="${LAST%.*}.$(( ${LAST##*.} + 1 ))"; fi
fi
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "✗ Version must be X.Y.Z"; exit 1; }
TAG="v$VERSION"
NOTES="${2:-Tabby $VERSION}"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && { echo "✗ $TAG already exists"; exit 1; }

# A build number Sparkle can compare: it only ever grows.
BUILD_NUMBER="$(git rev-list --count HEAD)"
echo "→ Releasing $TAG (build $BUILD_NUMBER)"

git push origin main
VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" ./Scripts/build-app.sh
./Scripts/make-dmg.sh
DMG="dist/Tabby.dmg"

echo "→ Publishing GitHub release"
gh release create "$TAG" "$DMG" --repo "$REPO" --target "$(git rev-parse HEAD)" \
    --title "Tabby $VERSION" --notes "$NOTES" --latest

echo "→ Updating appcast.xml and the Homebrew cask"
SIGNATURE="$("$SIGN_UPDATE" --ed-key-file "$KEY" "$DMG")"
VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" SIGNATURE="$SIGNATURE" NOTES="$NOTES" \
URL="https://github.com/$REPO/releases/download/$TAG/Tabby.dmg" python3 - <<'PY'
import html, os, pathlib
from email.utils import formatdate
e = os.environ
item = f"""    <item>
      <title>{e['VERSION']}</title>
      <pubDate>{formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{e['BUILD_NUMBER']}</sparkle:version>
      <sparkle:shortVersionString>{e['VERSION']}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[<p>{html.escape(e['NOTES'])}</p>]]></description>
      <enclosure url="{e['URL']}" type="application/octet-stream" {e['SIGNATURE']} />
    </item>
"""
path = pathlib.Path("appcast.xml")
marker = "<language>en</language>\n"
text = path.read_text()
path.write_text(text.replace(marker, marker + item, 1))
PY
SHA="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"
sed -i '' -E -e "s/^  version \"[^\"]*\"/  version \"$VERSION\"/" -e "s/^  sha256 \"[^\"]*\"/  sha256 \"$SHA\"/" Casks/tabby.rb
grep -q "$SHA" Casks/tabby.rb

git add appcast.xml Casks/tabby.rb
git commit -m "Release $VERSION: update appcast and cask"
git push origin main
echo "✓ Released $TAG — https://github.com/$REPO/releases/tag/$TAG"
