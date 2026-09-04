# Brewfile - new Mac, curated 2026-09-04
#
# Apply with:  brew bundle --file=Brewfile
# Verify with: brew bundle check --file=Brewfile
#
# Deliberately NOT here:
#   docker          comes from the LEGO app store
#   Xcode           App Store, or `xcodes install --latest`
#   twg             own installer
#   node/python/etc mise, see setup-new-mac.sh

tap "databricks/tap"
tap "grafana/grafana"
tap "jandedobbeleer/oh-my-posh"
tap "lego/tap", "git@github.com:LEGO/homebrew-tap.git"
tap "pulumi/tap"

# Shell and terminal
brew "bash"
brew "coreutils"
brew "fzf"
brew "jandedobbeleer/oh-my-posh/oh-my-posh"
brew "stow"
brew "tmux"
brew "zoxide"

# Everyday CLI
brew "jq"
brew "wget"
# 15 history uses, 9 recent. Was hand-installed in ~/.local/bin.
brew "yt-dlp"

# Zero uses in 9,164 history entries. Uncomment if you miss them.
# brew "bat"
# brew "htop"
# brew "httpie"
# brew "yq"

# Language servers, for the agents' LSP integration and any editor.
#   TypeScript  typescript-language-server, via mise npm
#   C#          csharp-ls + roslyn-language-server, via dotnet tool
#   Rust        rust-analyzer, ships with rustup
#   Python      pyright (types) + ruff (lint and format, `ruff server`)
#   Go          gopls
brew "pyright"
brew "ruff"
brew "gopls"

# Git and code quality
brew "gh"
brew "git-filter-repo"
brew "git-lfs"
brew "lefthook"
brew "shellcheck"

# mise is NOT here on purpose. It installs via https://mise.run into
# ~/.local/bin so that `mise self-update` works, which brew-installed mise
# refuses. setup-new-mac.sh handles it.
brew "uv"

# .NET. Inspectra and the other backends. 48 recent uses.
brew "dotnet"

# Node package manager. 37 of its 40 lifetime uses are recent.
brew "pnpm"

# Ansible. 104 recent uses, the most-used tool that was missing.
# Deliberately brew, not pip into a mise python, see setup-new-mac.sh.
brew "ansible"

# Secrets and signing
brew "gnupg"
brew "pinentry-mac"

# Azure
brew "azure-cli"
brew "azcopy"

# Postgres client. postgresql@16 is keg-only, see setup-new-mac.sh for the PATH line
brew "libpq"
brew "postgresql@16"

# Infrastructure. 37 recent pulumi uses.
brew "pulumi/tap/pulumi"
brew "rclone"

# Kubernetes. kubectl gets its config from `novus kztp update-kubeconfig`,
# but the binary is separate. Yours currently comes from Docker Desktop at
# /usr/local/bin, which is fragile, so own it here instead.
brew "kubernetes-cli"

# helm and kustomize: you asked for them, but history shows zero uses ever.
brew "helm"
brew "kustomize"

# Observability and data platforms
brew "databricks/tap/databricks"
brew "grafana/grafana/gcx"
brew "sentry-cli"

# LEGO internal. amma-cli comes from lego/tap (v0.12.2), not the
# lego/amma-cli tap which is stuck on 0.10.2.
brew "lego/tap/amma-cli"
brew "lego/tap/edgectl"
brew "lego/tap/novus-cli"

# Pulsar, used by Inspectra
brew "pulsarctl"

# Apps
cask "bruno"
cask "drawio"
cask "iterm2"
cask "powershell"

# Nerd font for oh-my-posh
cask "font-fira-code-nerd-font"
