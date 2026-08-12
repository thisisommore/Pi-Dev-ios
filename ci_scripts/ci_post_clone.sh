#!/bin/zsh
# Xcode Cloud: Swift macro trust — restore only the explicitly trusted macros
# by copying the project's macros.json into Xcode Cloud's SwiftPM security dir.
#
# This is the SAFE alternative to:
#   defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
# which trusts ALL macro packages (a security risk). Instead we install the same
# macros.json that a developer has already approved locally, so only those exact
# fingerprints are trusted.
#
# NOTE: when you bump a macro package (e.g. swift-perception, swift-dependencies),
# its fingerprint changes. Re-export ~/Library/org.swift.swiftpm/security/macros.json
# into ci_scripts/macros.json and commit it together with the package bump.

set -euo pipefail

# Resolve script dir so we work regardless of the working directory.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MACROS_SRC="$SCRIPT_DIR/macros.json"
MACROS_DEST="$HOME/Library/org.swift.swiftpm/security/macros.json"

if [[ ! -f "$MACROS_SRC" ]]; then
  echo "warning: macros.json not found at $MACROS_SRC; skipping macro trust setup."
  exit 0
fi

mkdir -p "$(dirname "$MACROS_DEST")"
cp "$MACROS_SRC" "$MACROS_DEST"

echo "Installed trusted Swift macros from $MACROS_SRC to $MACROS_DEST"
