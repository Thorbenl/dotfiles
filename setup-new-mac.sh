#!/usr/bin/env bash
#
# Bootstrap a new Mac: Xcode Command Line Tools, Homebrew, Brewfile, mise.
#
# Usage:
#   ./setup-new-mac.sh              full run
#   ./setup-new-mac.sh --check      report what is missing, change nothing
#
# Safe to re-run. Every step checks before it acts.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREWFILE="$SCRIPT_DIR/Brewfile"

# Completed steps leave a marker here, so a re-run resumes instead of redoing
# everything. Delete a marker to force that one step.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/new-mac"

CHECK_ONLY=false
FORCE=false
LIST_ONLY=false

while [ $# -gt 0 ]; do
	case "$1" in
	--check) CHECK_ONLY=true ;;
	--force) FORCE=true ;;
	--list) LIST_ONLY=true ;;
	-h | --help)
		cat <<'USAGE'
setup-new-mac.sh [--check] [--force] [--list]

  (no flags)  Run every step that has not completed yet.
  --check     Report what is missing. Changes nothing.
  --force     Re-run every step, ignoring completion markers.
  --list      Show which steps have completed.

Safe to re-run. A failed step stops the script; fix the cause and run again,
and the steps that already succeeded are skipped.
USAGE
		exit 0
		;;
	*)
		printf 'Unknown option: %s (try --help)\n' "$1" >&2
		exit 1
		;;
	esac
	shift
done

STEPS="dirs xcode homebrew shell_env brewfile mise runtimes rust cargo_tools dotnet_tools uv_tools repos stow twg"

if [ "$(uname -m)" = "arm64" ]; then
	BREW_PREFIX=/opt/homebrew
else
	BREW_PREFIX=/usr/local
fi

info() { printf '\033[34m[*]\033[0m %s\n' "$1"; }
success() { printf '\033[32m[+]\033[0m %s\n' "$1"; }
warn() { printf '\033[33m[!]\033[0m %s\n' "$1"; }
err() { printf '\033[31m[x]\033[0m %s\n' "$1" >&2; }

# Append a line to a file only if it is not already there.
add_line_once() {
	local file="$1" line="$2"
	touch "$file"
	if grep -qxF "$line" "$file"; then
		return 0
	fi
	printf '%s\n' "$line" >>"$file"
	info "Added to ${file/#$HOME/~}: $line"
}

# Run a named step unless it already completed. On failure, stop so the cause
# can be fixed; the markers left behind make the next run resume.
run_step() {
	local name="$1" fn="$2"
	local marker="$STATE_DIR/$name.done"

	if $CHECK_ONLY; then
		"$fn"
		return 0
	fi
	if [ -f "$marker" ] && ! $FORCE; then
		success "$name: already done, skipping"
		return 0
	fi
	if "$fn"; then
		mkdir -p "$STATE_DIR"
		: >"$marker"
	else
		err "Step '$name' failed. Fix the cause and re-run."
		err "Completed steps will be skipped. Markers: $STATE_DIR"
		exit 1
	fi
}

list_steps() {
	printf 'Step status (%s)\n\n' "$STATE_DIR"
	local s
	for s in $STEPS; do
		if [ -f "$STATE_DIR/$s.done" ]; then
			printf '  \033[32mdone\033[0m     %s\n' "$s"
		else
			printf '  \033[33mpending\033[0m  %s\n' "$s"
		fi
	done
}

setup_directories() {
	# Directories that config, PATH entries and skills assume already exist.
	# Cheap, no dependencies, so this runs first.
	#   path|why it is needed
	local specs=(
		"work|Work repos. opencode.json points at work/sap-mcp-server"
		"work/api-specs|Local OpenAPI mirror the lego-api-specs skill writes to"
		"personalProjects|Kacky and other personal repos"
		"vaults|Obsidian vaults. OBS_VAULT=lego, used by the cap* functions"
		".local/bin|mise, twg, claude and uv install here. On PATH via .zprofile"
		"go/bin|GOBIN. On PATH via .zprofile, but go does not create it"
	)
	local spec path why

	for spec in "${specs[@]}"; do
		IFS='|' read -r path why <<<"$spec"
		if [ -d "$HOME/$path" ]; then
			success "Directory $path exists"
		elif $CHECK_ONLY; then
			warn "Directory $path missing ($why)"
		else
			mkdir -p "$HOME/$path"
			info "Created directory $path"
		fi
	done

	if ! $CHECK_ONLY && [ ! -d "$HOME/vaults/lego" ]; then
		warn "The vaults/lego directory is absent. The cap* functions"
		warn "write there. Restore or clone the vault separately."
	fi
}

need_xcode_clt() {
	if xcode-select -p >/dev/null 2>&1; then
		success "Xcode Command Line Tools present"
		return 0
	fi
	if $CHECK_ONLY; then
		warn "Xcode Command Line Tools missing"
		return 0
	fi

	info "Installing Xcode Command Line Tools"
	xcode-select --install || true
	info "Finish the installer window that just opened. Waiting."

	local waited=0
	until xcode-select -p >/dev/null 2>&1; do
		sleep 10
		waited=$((waited + 10))
		if [ "$waited" -ge 900 ]; then
			err "Still not installed after 15 minutes. Finish the installer, then re-run."
			exit 1
		fi
	done
	success "Xcode Command Line Tools installed"
}

need_homebrew() {
	if [ -x "$BREW_PREFIX/bin/brew" ]; then
		success "Homebrew present at $BREW_PREFIX"
	elif $CHECK_ONLY; then
		warn "Homebrew missing"
		return 0
	else
		info "Installing Homebrew"
		NONINTERACTIVE=1 /bin/bash -c \
			"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		success "Homebrew installed"
	fi

	# Put brew on PATH for the rest of this script.
	if [ -x "$BREW_PREFIX/bin/brew" ]; then
		eval "$("$BREW_PREFIX/bin/brew" shellenv)"
	fi
}

wire_shell_env() {
	# If .zprofile is a symlink, stow owns it and the real file is in the
	# dotfiles repo. Appending would write through the link and dirty git,
	# so verify instead of modifying.
	if [ -L "$HOME/.zprofile" ]; then
		info "Your .zprofile is stow-managed, leaving it alone"
		local missing=0 entry
		for entry in ".local/bin" "go/bin" ".dotnet/tools" "postgresql@16" "Obsidian.app"; do
			grep -q "$entry" "$HOME/.zprofile" || {
				warn "Stowed .zprofile does not mention $entry"
				missing=1
			}
		done
		[ "$missing" -eq 0 ] && success "Stowed .zprofile covers every expected PATH entry"
		return 0
	fi

	$CHECK_ONLY && return 0

	# No dotfiles yet, so bootstrap a working login shell. These lines become
	# redundant once .zprofile from the dotfiles repo is stowed over them.
	add_line_once "$HOME/.zprofile" "eval \"\$($BREW_PREFIX/bin/brew shellenv)\""

	# postgresql@16 is keg-only, so psql is not linked into $BREW_PREFIX/bin.
	add_line_once "$HOME/.zprofile" "export PATH=\"$BREW_PREFIX/opt/postgresql@16/bin:\$PATH\""

	# twg and claude install themselves here, and it is not on PATH by default.
	add_line_once "$HOME/.zprofile" "export PATH=\"\$HOME/.local/bin:\$PATH\""

	# GOBIN. `go install` drops binaries here and nothing puts it on PATH,
	# so go-installed tools are unreachable without this.
	add_line_once "$HOME/.zprofile" "export PATH=\"\$HOME/go/bin:\$PATH\""

	# dotnet global tools, same problem.
	add_line_once "$HOME/.zprofile" "export PATH=\"\$HOME/.dotnet/tools:\$PATH\""

	# The obsidian binary. Your cap/caph/capw/capm/caps functions need it.
	add_line_once "$HOME/.zprofile" \
		"export PATH=\"/Applications/Obsidian.app/Contents/MacOS:\$PATH\""
}

run_brew_bundle() {
	if [ ! -f "$BREWFILE" ]; then
		err "No Brewfile next to this script at $BREWFILE"
		exit 1
	fi

	if $CHECK_ONLY; then
		info "Brewfile status"
		brew bundle check --file="$BREWFILE" --verbose || true
		return 0
	fi

	info "Installing from Brewfile. This is the long part."
	brew bundle --file="$BREWFILE"
	success "Brewfile applied"
}

install_mise() {
	if [ -x "$HOME/.local/bin/mise" ] || command -v mise >/dev/null 2>&1; then
		success "mise present"
		return 0
	fi
	if $CHECK_ONLY; then
		warn "mise missing"
		return 0
	fi

	# Deliberately not brew: the standalone install supports `mise self-update`.
	info "Installing mise from https://mise.run"
	if curl -fsSL https://mise.run | sh; then
		success "mise installed to ~/.local/bin"
	else
		err "mise install failed. Runtimes and coding agents depend on it."
		return 1
	fi
}

setup_mise() {
	# Resolve mise explicitly. ~/.local/bin is on PATH only for future
	# login shells at this point, not for this process.
	local mise="$HOME/.local/bin/mise"
	command -v mise >/dev/null 2>&1 && mise="$(command -v mise)"
	if [ ! -x "$mise" ]; then
		warn "mise not found, skipping runtime setup"
		return 0
	fi

	if $CHECK_ONLY; then
		info "mise tools"
		"$mise" ls --installed || true
		return 0
	fi

	# Language versions come from ~/.config/mise/config.toml, which your
	# dotfiles should provide. Without it, install a current node.
	# Baseline runtimes, set explicitly. ~/.config/mise/config.toml is not in
	# the dotfiles repo, so this script has to be the source of truth for it.
	# Writing them here means a fresh machine works before dotfiles are cloned.
	info "Setting global runtimes"
	"$mise" use -g node@lts
	"$mise" use -g python@3.14
	# Go via mise rather than brew, so multiple versions are switchable the
	# way go.dev/doc/manage-install describes, without the golang.org/dl dance.
	# Pin to go@1.27 instead of latest if a major bump would be unwelcome.
	"$mise" use -g go@latest

	# Then install anything else the config picked up (java, pre-commit, ...).
	if [ -f "$HOME/.config/mise/config.toml" ]; then
		"$mise" install
	fi

	# Coding agents through the mise npm backend rather than plain `npm -g`.
	# A global under a mise-managed node disappears when the node version moves.
	info "Installing coding agents via the mise npm backend"
	"$mise" use -g npm:@anthropic-ai/claude-code || warn "claude-code install failed, do it by hand"
	"$mise" use -g npm:@openai/codex || warn "codex install failed, do it by hand"

	# npm globals worth keeping.
	"$mise" use -g npm:defuddle || warn "defuddle install failed"
	"$mise" use -g npm:npm-check-updates || warn "npm-check-updates install failed"
	"$mise" use -g npm:typescript-language-server || warn "typescript-language-server install failed"
	"$mise" use -g npm:@playwright/cli || warn "playwright cli install failed"

	# ctx7 replaces the context7 MCP server. Context7 ships a CLI + skill
	# mode explicitly as the no-MCP path, which is cheaper in context and
	# has no server process. Run `ctx7 setup --opencode` once to auth.
	"$mise" use -g npm:ctx7 || warn "ctx7 install failed"

	success "mise configured"
	info "Playwright browsers are a separate download: npx playwright install"
}

install_rust() {
	if [ -x "$HOME/.cargo/bin/rustup" ] || command -v rustup >/dev/null 2>&1; then
		success "Rust toolchain present"
		return 0
	fi
	if $CHECK_ONLY; then
		warn "Rust toolchain missing"
		return 0
	fi

	# -y makes it unattended. Without it rustup stops on a menu prompt.
	# rustup writes ~/.cargo/env and sources it from ~/.zshenv itself, so
	# ~/.cargo/bin needs no PATH handling from this script.
	info "Installing Rust via rustup"
	if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
		success "Rust installed to ~/.cargo/bin"
	else
		err "rustup install failed. ProjectAtlas needs cargo."
		return 1
	fi
}

install_cargo_tools() {
	local cargo="$HOME/.cargo/bin/cargo"
	command -v cargo >/dev/null 2>&1 && cargo="$(command -v cargo)"

	if [ ! -x "$cargo" ]; then
		warn "cargo not found, skipping ProjectAtlas"
		return 0
	fi
	if $CHECK_ONLY; then
		info "cargo tools"
		"$cargo" install --list 2>/dev/null | grep -v '^ ' || true
		return 0
	fi

	# Pinned to the version you run today. Bump the tag to upgrade, or drop
	# --tag to track the default branch.
	info "Installing ProjectAtlas (this compiles from source, it takes a while)"
	if "$cargo" install --git https://github.com/styler-ai/ProjectAtlas --tag v0.4.4; then
		success "ProjectAtlas installed"
	else
		warn "ProjectAtlas install failed, do it by hand:"
		warn "  cargo install --git https://github.com/styler-ai/ProjectAtlas --tag v0.4.4"
	fi
}

install_dotnet_tools() {
	local dotnet="$BREW_PREFIX/bin/dotnet"
	command -v dotnet >/dev/null 2>&1 && dotnet="$(command -v dotnet)"

	if [ ! -x "$dotnet" ]; then
		warn "dotnet not found, skipping global tools"
		return 0
	fi
	if $CHECK_ONLY; then
		info "dotnet global tools"
		"$dotnet" tool list --global 2>/dev/null || true
		return 0
	fi

	# Package IDs taken from `dotnet tool list --global`, not guessed.
	# dotnet-ef is the important one: 110 history uses as `dotnet ef`.
	# csharp-ls and roslyn-language-server are never typed, the agents and
	# editors launch them, which is why DOTNET_ROOT is set in .zprofile.
	local pkg
	for pkg in dotnet-ef csharp-ls roslyn-language-server \
		microsoft.sqlpackage; do
		if "$dotnet" tool list --global 2>/dev/null | grep -qi "^$pkg "; then
			success "dotnet tool $pkg already installed"
		else
			info "Installing dotnet tool $pkg"
			"$dotnet" tool install --global "$pkg" || warn "$pkg failed"
		fi
	done
}

install_uv_tools() {
	local uv="$BREW_PREFIX/bin/uv"
	command -v uv >/dev/null 2>&1 && uv="$(command -v uv)"

	if [ ! -x "$uv" ]; then
		warn "uv not found, skipping uv tools"
		return 0
	fi
	if $CHECK_ONLY; then
		info "uv tools"
		"$uv" tool list 2>/dev/null || true
		return 0
	fi

	# graphifyy provides the graphify and graphify-mcp commands.
	info "Installing graphifyy via uv"
	"$uv" tool install graphifyy || warn "graphifyy failed"
}

clone_repos() {
	# Repos that config files point at. Without these, the MCP entry in
	# opencode.json resolves to a missing path and the server silently fails.
	# name|destination|clone target
	local specs=(
		"sap-mcp-server|$HOME/work/sap-mcp-server|LEGO/sap-mcp-server"
	)
	local spec name dest repo

	if $CHECK_ONLY; then
		for spec in "${specs[@]}"; do
			IFS='|' read -r name dest repo <<<"$spec"
			if [ -d "$dest/.git" ]; then
				success "$name cloned"
			else
				warn "$name missing at ${dest/#$HOME/~}"
			fi
		done
		return 0
	fi

	for spec in "${specs[@]}"; do
		IFS='|' read -r name dest repo <<<"$spec"
		if [ -d "$dest/.git" ]; then
			success "$name already cloned"
			continue
		fi
		mkdir -p "$(dirname "$dest")"
		info "Cloning $repo"
		# gh handles the internal-repo auth that plain git clone does not.
		if gh repo clone "$repo" "$dest"; then
			success "$name cloned to ${dest/#$HOME/~}"
		else
			warn "$repo clone failed. It is INTERNAL, so run 'gh auth login' first."
		fi
	done
}

stow_dotfiles() {
	local repo="$HOME/dotfiles" pkg="home"

	if [ ! -d "$repo/$pkg" ]; then
		info "No $repo/$pkg package, skipping stow"
		info "Flat repo layouts are not stowable: stow would link README.md"
		info "and the shell scripts into your home directory too."
		return 0
	fi
	if ! command -v stow >/dev/null 2>&1; then
		warn "stow not installed, skipping"
		return 0
	fi
	if $CHECK_ONLY; then
		info "Would stow $repo/$pkg into $HOME"
		return 0
	fi

	# stow refuses to link over a real file. This script writes a bootstrap
	# .zprofile, so move any conflicting real file aside rather than deleting.
	local f
	for f in .zshrc .zprofile .zshenv; do
		if [ -e "$HOME/$f" ] && [ ! -L "$HOME/$f" ]; then
			mv "$HOME/$f" "$HOME/$f.pre-stow"
			warn "Moved existing $f to $f.pre-stow so stow can link it"
		fi
	done

	info "Stowing $pkg into $HOME"
	if stow --dir="$repo" --target="$HOME" "$pkg"; then
		success "Dotfiles linked"
	else
		warn "stow failed. Resolve the conflicts it listed, then re-run."
	fi
}

install_twg() {
	if command -v twg >/dev/null 2>&1 || [ -x "$HOME/.local/bin/twg" ]; then
		success "twg present"
		return 0
	fi
	if $CHECK_ONLY; then
		warn "twg missing"
		return 0
	fi

	info "Installing twg from the Atlassian installer"
	if curl -fsSL --retry 2 https://teamwork-graph.atlassian.com/cli/install | bash; then
		success "twg installed to ~/.local/bin"
	else
		warn "twg install failed. Run it by hand:"
		warn "  curl -fsSL --retry 2 https://teamwork-graph.atlassian.com/cli/install | bash"
	fi
}

print_manual_steps() {
	cat <<'EOF'

--------------------------------------------------------------------
Still to do by hand. Nothing above installs these.
--------------------------------------------------------------------

  docker      LEGO app store. Brings kubectl with it, so kubectl is not in the Brewfile
  Xcode       App Store
  1Password   LEGO app store

Then, in this order. Cloning must come before the new terminal, because the
shell config arrives with the dotfiles.

  1. git clone git@github.com:Thorbenl/dotfiles.git ~/dotfiles
  2. Re-run this script. It stows ~/dotfiles/home and moves any conflicting
     real file aside as <name>.pre-stow.
  3. Create the secrets file, which .zprofile sources but does not contain:
       touch ~/.zsh_secrets && chmod 600 ~/.zsh_secrets
       echo 'export LEGO_GENAI_TOKEN=...' >> ~/.zsh_secrets
  4. Open a new terminal.
  5. gh auth login && az login
  6. ./setup-new-mac.sh --check

What gets stowed lives in home/. Everything else in the repo stays put.
Add a new dotfile by dropping it at its $HOME-relative path under home/,
eg home/.config/foo/bar.toml, then re-run with --force.

Dropped after checking 9,164 shell-history entries. All had zero recent use.
Add back if you miss them:
  terraform, terraformer, lazy-pulumi, saml2aws, cf-cli@8, nats, mysql-client,
  mariadb-connector-c, redis, redli, mssql-tools18, msodbcsql18, go, yarn,
  rbenv, python@3.12, ffmpeg, poppler, jwt-ui, nmap, bind, rename, aichat, ata,
  kimi-code, mailsy, taskell, wifi-password, putty, xquartz, alt-tab, jitouch,
  discord, cf-terraforming, github-copilot-for-xcode, xcodes, bun, bat, htop,
  httpie, yq

Low but non-zero use, decide for yourself:
  freerdp (5), fastlane (4), crowdin (4), redis (3), speedtest (2)

Not needed: make and nano and netcat ship with macOS. GNU Make 3.81 from the
Xcode tools has served 101 recent invocations, so brew's gmake is unnecessary.

EOF
}

main() {
	if $LIST_ONLY; then
		list_steps
		exit 0
	fi
	if $CHECK_ONLY; then
		info "Check mode. Nothing will be changed."
	fi
	if $FORCE; then
		info "Force mode. Completion markers ignored."
	fi

	run_step dirs         setup_directories
	run_step xcode        need_xcode_clt
	run_step homebrew     need_homebrew
	run_step shell_env    wire_shell_env
	run_step brewfile     run_brew_bundle
	run_step mise         install_mise
	run_step runtimes     setup_mise
	run_step rust         install_rust
	run_step cargo_tools  install_cargo_tools
	run_step dotnet_tools install_dotnet_tools
	run_step uv_tools     install_uv_tools
	run_step repos        clone_repos
	run_step stow         stow_dotfiles
	run_step twg          install_twg

	$CHECK_ONLY || success "Done"
	print_manual_steps
}

main
