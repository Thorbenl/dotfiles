#!/usr/bin/env bash
#
# One-command bootstrap for a new Mac.
#
#   curl -fsSL https://raw.githubusercontent.com/Thorbenl/dotfiles/main/dotfiles.sh | bash
#
# Clones this repo, then hands over to setup-new-mac.sh, which is resumable.

set -o errexit
set -o nounset
set -o pipefail

REPO_URL="https://github.com/Thorbenl/dotfiles.git"
REPO_PATH="$HOME/dotfiles"

info() { printf '\033[34m[*]\033[0m %s\n' "$1"; }

if ! xcode-select -p >/dev/null 2>&1; then
	info "Installing Xcode Command Line Tools first, git needs them"
	xcode-select --install || true
	until xcode-select -p >/dev/null 2>&1; do sleep 10; done
fi

if [ -d "$REPO_PATH/.git" ]; then
	info "$REPO_PATH already exists, pulling"
	git -C "$REPO_PATH" pull --ff-only || true
else
	info "Cloning $REPO_URL into $REPO_PATH"
	git clone "$REPO_URL" "$REPO_PATH"
fi

info "Handing over to setup-new-mac.sh"
exec "$REPO_PATH/setup-new-mac.sh" "$@"
