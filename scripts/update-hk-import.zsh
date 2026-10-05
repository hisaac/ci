#!/usr/bin/env zsh

source "${0:A:h}/lib/common.zsh" || exit 1

# Example import headers to be updated:
# amends "package://github.com/jdx/hk/releases/download/v2.0.1/hk@2.0.1#/Config.pkl"
# import "package://github.com/jdx/hk/releases/download/v2.0.1/hk@2.0.1#/Builtins.pkl"

function main {
	readonly config_path="${PROJECT_ROOT}/hk.pkl"
	if [[ ! -f "${config_path}" ]]; then
		log_error "Config file not found: ${config_path}"
		exit 1
	fi

	local hk_version
	hk_version="$(hk version | head -n 1)"
	readonly hk_version

	log_info "Updating hk imports in ${config_path} to version ${hk_version}"

	# Rewrite matching package URLs without relying on platform-specific sed -i behavior.
	local temp_path
	temp_path="$(mktemp "${TMPDIR:-/tmp}/update-hk-import.XXXXXX")"
	readonly temp_path

	{
		sed -E \
			"s|package://github\.com/jdx/hk/releases/download/v[^/]+/hk@[^#]+#/|package://github.com/jdx/hk/releases/download/v${hk_version}/hk@${hk_version}#/|g" \
			"${config_path}" >"${temp_path}"
		cat "${temp_path}" >"${config_path}"
	} always {
		rm -f -- "${temp_path}"
	}
}

main "$@"
