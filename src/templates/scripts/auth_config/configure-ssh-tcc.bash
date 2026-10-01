#!/bin/bash -euo pipefail

# For the SIP-disabled macOS 27 CI guest only. TCC is a private macOS database.
# Discovery follows https://github.com/cirruslabs/macos-image-templates/blob/main/scripts/update-tcc-database.sh
function resolve_user_tcc_database() {
	local -r user_id="${1}"
	local open_files line candidate database=""
	if ! open_files=$(sudo -n lsof -a -u "${user_id}" -c tccd -Fn); then
		echo "Unable to inspect the user TCC daemon for UID ${user_id}" >&2
		return 1
	fi

	# macOS 27 uses a ProtectedSystem container; ignore stale legacy copies and WALs.
	while IFS= read -r line; do
		case "${line}" in
		n/private/var/containers/Data/ProtectedSystem/*/Data/Library/Application\ Support/com.apple.TCC/TCC.db)
			candidate="${line#n}"
			if [[ -n "${database}" && "${database}" != "${candidate}" ]]; then
				echo "Found multiple active user TCC databases for UID ${user_id}" >&2
				return 1
			fi
			database="${candidate}"
			;;
		esac
	done <<<"${open_files}"
	if [[ -z "${database}" ]]; then
		echo "Unable to find the active macOS 27 user TCC database for UID ${user_id}" >&2
		return 1
	fi
	printf '%s\n' "${database}"
}

function main() {
	local -r data_dir="${DATA_DIRECTORY:?DATA_DIRECTORY must point to the staged configuration directory}"
	local -r sql_dir="${data_dir}/tcc"
	local -r system_database="/Library/Application Support/com.apple.TCC/TCC.db"
	local user_id user_database database sql_file schema_check
	for sql_file in check-schema.sql grant-ssh-accessibility.sql grant-ssh-automation.sql; do
		if [[ ! -r "${sql_dir}/${sql_file}" ]]; then
			echo "SQL file is not readable: ${sql_dir}/${sql_file}" >&2
			return 1
		fi
	done
	schema_check=$(cat "${sql_dir}/check-schema.sql")
	if ! csrutil status | grep -Fxq 'System Integrity Protection status: disabled.'; then
		echo "SIP must be disabled by the recovery stage before granting CI permissions" >&2
		return 1
	fi
	user_id=$(id -u)
	if [[ "${user_id}" == 0 ]]; then
		echo "Run as the VM user, not root, to select the correct user TCC database" >&2
		return 1
	fi
	user_database=$(resolve_user_tcc_database "${user_id}")

	# Validate both databases before changing either; never create a missing TCC.db.
	for database in "${system_database}" "${user_database}"; do
		if ! sudo -n test -f "${database}"; then
			echo "TCC database does not exist: ${database}" >&2
			return 1
		fi
	done
	if [[ "$(sudo -n stat -f %u "${user_database}")" != "${user_id}" ]]; then
		echo "Unexpected owner for user TCC database: ${user_database}" >&2
		return 1
	fi
	for database in "${system_database}" "${user_database}"; do
		sudo -n sqlite3 -bail -cmd '.timeout 5000' "${database}" \
			"${schema_check}"
	done

	echo "Granting SSH-wrapper Accessibility and System Events Automation access..."
	# The VM user reads the staged SQL; only SQLite needs elevated database access.
	# shellcheck disable=SC2024
	sudo -n sqlite3 -bail -cmd '.timeout 5000' "${system_database}" \
		<"${sql_dir}/grant-ssh-accessibility.sql"
	# shellcheck disable=SC2024
	sudo -n sqlite3 -bail -cmd '.timeout 5000' "${user_database}" \
		<"${sql_dir}/grant-ssh-automation.sql"
}

main "$@"
