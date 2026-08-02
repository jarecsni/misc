#!/usr/bin/env bash
# install.sh - install dependencies and wire display-modes.zsh into ~/.zshrc
# Idempotent: safe to re-run. Backs up ~/.zshrc before touching it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC="$HOME/.zshrc"
BEGIN="# >>> display-modes >>>"
END="# <<< display-modes <<<"

echo "==> Checking Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  echo "    Homebrew not found. Install it from https://brew.sh and re-run." >&2
  exit 1
fi

echo "==> Installing dependencies"
brew list --cask betterdisplay >/dev/null 2>&1 \
  || brew install --cask betterdisplay
brew list betterdisplaycli >/dev/null 2>&1 \
  || brew install waydabber/betterdisplay/betterdisplaycli
brew list nightlight >/dev/null 2>&1 \
  || brew install smudge/smudge/nightlight

echo "==> Wiring into $ZSHRC"
if [ -f "$ZSHRC" ]; then
  cp "$ZSHRC" "$ZSHRC.bak.$(date +%Y%m%d%H%M%S)"
  # strip any previous block so re-running does not duplicate it
  /usr/bin/sed -i '' "/^${BEGIN}\$/,/^${END}\$/d" "$ZSHRC"
fi

cat >> "$ZSHRC" <<EOF
${BEGIN}
source "${SCRIPT_DIR}/display-modes.zsh"
${END}
EOF

cat <<'DONE'

==> Done.

Next steps:
  1. Launch BetterDisplay.app (the CLI needs the app running).
  2. source ~/.zshrc
  3. Confirm the display name:  betterdisplaycli get --identifiers
     If it is not "Built-in Display", edit DISPLAY_NAME in display-modes.zsh.
  4. Commands available:  photomode  daymode  displaystatus

DONE
