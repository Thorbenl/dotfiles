# ~/.zprofile - login shells. Environment and PATH only.
#
# Split of responsibility:
#   .zshenv   always sourced. rustup owns it (sources ~/.cargo/env).
#   .zprofile this file. PATH and exported environment.
#   .zshrc    interactive only. Prompt, plugins, keybindings, aliases.
#
# Secrets are NOT in here. They live in ~/.zsh_secrets, which is gitignored.

# ---------------------------------------------------------------- Homebrew ---
# First, because everything below can depend on it. Sets HOMEBREW_PREFIX.
if [ -x /opt/homebrew/bin/brew ]; then
	eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
	eval "$(/usr/local/bin/brew shellenv)"
fi

# -------------------------------------------------------------------- PATH ---
# postgresql@16 is keg-only, so psql/pg_dump are not linked into the prefix.
export PATH="$HOMEBREW_PREFIX/opt/postgresql@16/bin:$PATH"

# mise, twg, claude, uv all install themselves here.
export PATH="$HOME/.local/bin:$PATH"

# `go install` drops binaries in GOBIN and nothing else puts it on PATH.
export PATH="$HOME/go/bin:$PATH"

# `dotnet tool install --global` lands here.
export PATH="$HOME/.dotnet/tools:$PATH"

# The obsidian CLI. The cap/caph/capw/capm/caps functions in .zshrc need this.
export PATH="/Applications/Obsidian.app/Contents/MacOS:$PATH"

# ~/.cargo/bin is deliberately absent: rustup adds it via ~/.zshenv.

# ------------------------------------------------------------ Environment ----
export EDITOR="nano"
export VISUAL="nano"

# Needed by csharp-lsp and MSBuildLocator to find the Homebrew dotnet.
export DOTNET_ROOT="$HOMEBREW_PREFIX/opt/dotnet/libexec"

# ----------------------------------------------------------------- Secrets ---
# Create with:  touch ~/.zsh_secrets && chmod 600 ~/.zsh_secrets
# Never commit it. See .gitignore.
[ -f "$HOME/.zsh_secrets" ] && source "$HOME/.zsh_secrets"
