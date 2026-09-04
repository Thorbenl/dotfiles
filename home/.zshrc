# ~/.zshrc - interactive shells only.
# PATH and exported environment live in .zprofile. Secrets in ~/.zsh_secrets.

# ------------------------------------------------------------------ Prompt ---
# Guarded: a missing binary would otherwise error on every new shell.
if command -v oh-my-posh >/dev/null 2>&1; then
	eval "$(oh-my-posh init zsh --config "$HOME/oh-my-posh/themes/amro.omp.json")"
fi

export GPG_TTY=$(tty)

# ------------------------------------------------------------------- zinit ---
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
	mkdir -p "$(dirname "$ZINIT_HOME")"
	git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

zinit light-mode for \
	zdharma-continuum/zinit-annex-as-monitor \
	zdharma-continuum/zinit-annex-bin-gem-node \
	zdharma-continuum/zinit-annex-patch-dl \
	zdharma-continuum/zinit-annex-rust

# fpath must be complete BEFORE compinit, which now runs inside the turbo
# block below via zicompinit.
fpath+=("$HOMEBREW_PREFIX/share/zsh/site-functions")
[ -d "$HOME/.docker/completions" ] && fpath+=("$HOME/.docker/completions")

# ------------------------------------------------- Plugins, in turbo mode ----
# `wait lucid` defers all of this until after the prompt is drawn. compinit
# was 89% of startup when loaded synchronously, so it moves here too, via
# zicompinit. Order matters: fzf-tab must come after compinit has run.
# Loaded synchronously, on purpose. zinit turbo mode (`wait lucid`) halved
# startup but silently broke two things: the OMZ git aliases including gco,
# which has 709 uses in shell history, and fzf-tab, which loaded 16 functions
# synchronously and zero deferred. Turbo is worth revisiting by hand in a real
# terminal; it is not worth shipping unverified.
zinit ice depth=1
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::docker

autoload -Uz compinit
# Rebuild the dump only if it is older than 24h, otherwise trust the cache.
# ${ZDOTDIR:-$HOME} matters: ZDOTDIR is unset here, so a bare ${ZDOTDIR} would
# test /.zcompdump, never match, and always take the -C branch.
# compinit -C also skips compaudit, which zprof measured at 36ms.
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
	compinit
	# Byte-compile the dump so later shells parse bytecode, not source.
	# Backgrounded and detached so it never delays the prompt.
	{ zcompile -R -- "${ZDOTDIR:-$HOME}/.zcompdump" } &!
else
	compinit -C
fi

zinit cdreplay -q

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# ------------------------------------------------------------- Keybindings ---
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region

# ----------------------------------------------------------------- History ---
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=$HISTSIZE

# extended_history writes timestamps. Without it history cannot be analysed
# by date, only by frequency.
setopt extended_history
setopt append_history
setopt share_history
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_find_no_dups

# ----------------------------------------------------------------- Aliases ---
alias ls='ls --color'
alias c='clear'

# ------------------------------------------------------- Shell integrations ---
command -v fzf >/dev/null 2>&1 && eval "$(fzf --zsh)"

# zoxide replaces cd. Initialised once, with --cmd cd.
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init --cmd cd zsh)"

# mise. Resolved rather than hardcoded, because it installs to ~/.local/bin
# via mise.run, not to the Homebrew prefix.
if command -v mise >/dev/null 2>&1; then
	eval "$(mise activate zsh)"
elif [ -x "$HOME/.local/bin/mise" ]; then
	eval "$("$HOME/.local/bin/mise" activate zsh)"
fi

# -------------------------------------------------------- Obsidian capture ---
OBS_VAULT="lego"

cap() { # quick capture to daily note
	obsidian vault=$OBS_VAULT daily:append content="\n- $1"
	echo "Captured to daily note"
}

caph() { # high priority
	obsidian vault=$OBS_VAULT daily:append content="\n- $1 #this-week #priority"
	echo "Captured (priority)"
}

capw() { # next week
	obsidian vault=$OBS_VAULT daily:append content="\n- $1 #next-week"
	echo "Captured (next week)"
}

capm() { # meeting action item
	obsidian vault=$OBS_VAULT daily:append content="\n- $1 #this-week #meeting"
	echo "Captured (meeting)"
}

capl() { # leadership task
	obsidian vault=$OBS_VAULT daily:append content="\n- $1 #this-week #leadership"
	echo "Captured (leadership)"
}

caps() { # smart capture, Claude classifies and routes
	local input="$1"
	local today
	today=$(date +%Y-%m-%d)

	local result
	result=$(claude -p "Classify this capture for an Obsidian vault. Return ONLY a single line in this exact format:
TYPE|FOLDER|TAGS|TITLE
Where TYPE is 'standalone' or 'daily', FOLDER is one of: Work, Kacky, Personal, TAGS are space-separated hashtags from: #observation #decision #learning #kacky #this-week #next-week #priority #meeting #leadership #someday, and TITLE is a short specific title (no generic titles).
Examples:
standalone|Work|#decision|Use CQRS for Inspection API
standalone|Kacky|#kacky|Map Pool Rotation Strategy
daily|Personal|#someday|Look into new desk setup
Capture: $input" 2>/dev/null)

	local type folder tags title
	type=$(echo "$result" | head -1 | cut -d'|' -f1)
	folder=$(echo "$result" | head -1 | cut -d'|' -f2)
	tags=$(echo "$result" | head -1 | cut -d'|' -f3)
	title=$(echo "$result" | head -1 | cut -d'|' -f4)

	if [[ "$type" == "standalone" && -n "$title" ]]; then
		local content="# $title\n\n$tags - $today\n\n## What\n$input\n\n## Context\n\n\n## Open Questions\n- "
		obsidian vault=$OBS_VAULT create path="$folder/$title.md" content="$content"
		echo "Created: $folder/$title.md [$tags]"
	else
		obsidian vault=$OBS_VAULT daily:append content="\n- $input $tags"
		echo "Appended to daily note [$tags]"
	fi
}
