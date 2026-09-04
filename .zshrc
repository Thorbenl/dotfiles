eval "$(oh-my-posh init zsh --config ~/oh-my-posh/themes/amro.omp.json)"
BREW_PREFIX="/opt/homebrew"
if [ -f "$BREW_PREFIX/etc/brew-wrap" ]; then
  source "$BREW_PREFIX/etc/brew-wrap"
fi

if [[ -f "/opt/homebrew/bin/brew" ]] then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
[ -f "$HOME/.zsh_secrets" ] && source "$HOME/.zsh_secrets"
export GPG_TTY=$(tty)

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

zinit ice depth=1;

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Add in snippets
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::docker

# Load completions
autoload -Uz compinit

# Cache compinit for faster startup (regenerate once daily)
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

zinit cdreplay -q

# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region

# History
HISTSIZE=50000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# Aliases
alias ls='ls --color'
alias c='clear'

# Shell integrations
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"

# Load zinit annexes
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

# PATH and environment
export PATH=$PATH:$HOME/.pulumi/bin
export VISUAL="nano"
export EDITOR="nano"

# Obsidian capture functions (using Obsidian CLI)
OBS_VAULT="lego"

cap() {  # quick capture to daily note
  obsidian vault=$OBS_VAULT daily:append content="\n- $1"
  echo "Captured to daily note"
}

caph() {  # high priority
  obsidian vault=$OBS_VAULT daily:append content="\n- $1 #this-week #priority"
  echo "Captured (priority)"
}

capw() {  # next week
  obsidian vault=$OBS_VAULT daily:append content="\n- $1 #next-week"
  echo "Captured (next week)"
}

capm() {  # meeting action item
  obsidian vault=$OBS_VAULT daily:append content="\n- $1 #this-week #meeting"
  echo "Captured (meeting)"
}

capl() {  # leadership task
  obsidian vault=$OBS_VAULT daily:append content="\n- $1 #this-week #leadership"
  echo "Captured (leadership)"
}

caps() {  # smart capture — Claude classifies and routes to the right place
  local input="$1"
  local today=$(date +%Y-%m-%d)

  local result=$(claude -p "Classify this capture for an Obsidian vault. Return ONLY a single line in this exact format:
TYPE|FOLDER|TAGS|TITLE
Where TYPE is 'standalone' or 'daily', FOLDER is one of: Work, Kacky, Personal, TAGS are space-separated hashtags from: #observation #decision #learning #kacky #this-week #next-week #priority #meeting #leadership #someday, and TITLE is a short specific title (no generic titles).
Examples:
standalone|Work|#decision|Use CQRS for Inspection API
standalone|Kacky|#kacky|Map Pool Rotation Strategy
daily|Personal|#someday|Look into new desk setup
Capture: $input" 2>/dev/null)

  local type=$(echo "$result" | head -1 | cut -d'|' -f1)
  local folder=$(echo "$result" | head -1 | cut -d'|' -f2)
  local tags=$(echo "$result" | head -1 | cut -d'|' -f3)
  local title=$(echo "$result" | head -1 | cut -d'|' -f4)

  if [[ "$type" == "standalone" && -n "$title" ]]; then
    local content="# $title\n\n$tags — $today\n\n## What\n$input\n\n## Context\n\n\n## Open Questions\n- "
    obsidian vault=$OBS_VAULT create path="$folder/$title.md" content="$content"
    echo "Created: $folder/$title.md [$tags]"
  else
    obsidian vault=$OBS_VAULT daily:append content="\n- $input $tags"
    echo "Appended to daily note [$tags]"
  fi
}

# Mise (replaces nvm, pyenv, etc.)
eval "$(/opt/homebrew/bin/mise activate zsh)"

# Docker CLI completions
fpath=(/Users/dkThoLue/.docker/completions $fpath)

# Build flags
LDFLAGS="-L/opt/homebrew/lib -L/opt/homebrew/opt/openssl@3/lib"
CPPFLAGS="-I/opt/homebrew/include -I/opt/homebrew/opt/openssl@3/include"
DYLD_LIBRARY_PATH=/opt/homebrew/opt/lzo/lib
fpath+=/opt/homebrew/share/zsh/site-functions

# Additional PATH entries
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:/Users/dkThoLue/depot_tools"

# pnpm
export PNPM_HOME="/Users/dkThoLue/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

eval "$(zoxide init zsh)"

# bun completions
[ -s "/Users/dkThoLue/.bun/_bun" ] && source "/Users/dkThoLue/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

alias claude-mem='/Users/dkThoLue/.bun/bin/bun "/Users/dkThoLue/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'

# .NET SDK root (Homebrew install) — needed by csharp-lsp / MSBuildLocator
export DOTNET_ROOT="/opt/homebrew/opt/dotnet/libexec"
