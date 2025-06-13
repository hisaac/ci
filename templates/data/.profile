export LANG=en_US.UTF-8

# Don't restore shell sessions
export SHELL_SESSIONS_DISABLE=1

# Set up Homebrew environment
eval "$(/opt/homebrew/bin/brew shellenv)"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
