# ~/.zshenv - sourced for EVERY zsh, interactive or not.
#
# Only rustup's line belongs here. It is what puts ~/.cargo/bin on PATH, which
# is why home/.zprofile deliberately leaves cargo out.
#
# This file is in the stow package on purpose. setup-new-mac.sh moves an
# existing ~/.zshenv aside as .zshenv.pre-stow before stowing; when the package
# did not provide a replacement that simply deleted it, and cargo and rustc
# vanished from every new shell.
. "$HOME/.cargo/env"
