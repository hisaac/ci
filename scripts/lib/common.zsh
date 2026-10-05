#!/usr/bin/env zsh

# Guard to ensure this file is not double-loaded
if ((${__common_zsh_loaded:-0})); then
	return 0
fi
__common_zsh_loaded=1

setopt ERR_EXIT NO_UNSET PIPE_FAIL

if [[ "${TRACE:-}" == true || "${DEBUG:-}" == true ]]; then
	setopt XTRACE
fi

# Set project-specific environment variables
: "${PROJECT_ROOT:=${0:A:h:h:h}}"
: "${ARTIFACTS_DIR:="${PROJECT_ROOT}/.artifacts"}"
: "${CACHE_DIR:="${PROJECT_ROOT}/.cache"}"
export PROJECT_ROOT ARTIFACTS_DIR CACHE_DIR

# Resolves to the calling script's name
readonly script_name="${ZSH_ARGZERO:t}"

function log_info {
	readonly message="${1:-}"
	print -r -u2 -- "[${script_name}] ${message}"
}

function log_error {
	readonly message="${1:-}"
	print -r -u2 -- "[${script_name}] ERROR: ${message}"
}

function TRAPZERR {
	readonly -i exit_code=$?
	readonly location="${funcfiletrace[1]}"
	log_error "Command failed (exit ${exit_code}) at ${location}"
	return "$exit_code"
}
