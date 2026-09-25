# Login and interactive startup files may both source this in the same shell.
if [ "${_profile_pid-}" = "$$" ]; then
	return
fi

export LANG=en_US.UTF-8

# Disable macOS Terminal session restoration
export SHELL_SESSIONS_DISABLE=1

current_shell="sh"
if [ -n "${ZSH_VERSION-}" ]; then
	current_shell="zsh"
elif [ -n "${BASH_VERSION-}" ]; then
	# macOS's `sh` is just Bash in compatibility mode, without Bash interactive hooks.
	# `shopt` is safe here because this branch only runs under Bash.
	# shellcheck disable=SC3044
	if [ "${0##*/}" != "sh" ] && [ "${0##*/}" != "-sh" ] && ! shopt -oq posix; then
		current_shell="bash"
	fi
fi

# Set up Homebrew environment
brew_path=$(command -v brew 2>/dev/null) || brew_path="/opt/homebrew/bin/brew"
if [ -x "$brew_path" ]; then
	export HOMEBREW_NO_AUTO_UPDATE=1
	export HOMEBREW_NO_INSTALL_CLEANUP=1
	eval "$("$brew_path" shellenv "$current_shell")"
fi
unset brew_path

# Set up mise environment
mise_path=$(command -v mise 2>/dev/null) || mise_path="$HOME/.local/bin/mise"
if [ -x "$mise_path" ]; then
	export MISE_NOT_FOUND_AUTO_INSTALL=0
	# Interactive shells that are either bash or zsh use mise's built-in activation command.
	# `sh` and all other shells have the shims directory added to the `$PATH` manually.
	if [ "${-#*i}" != "$-" ] && { [ "$current_shell" = "bash" ] || [ "$current_shell" = "zsh" ]; }; then
		eval "$("$mise_path" activate "$current_shell")"
	else
		export PATH="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims:${mise_path%/*}:$PATH"
	fi
fi
unset mise_path

unset current_shell
_profile_pid=$$
