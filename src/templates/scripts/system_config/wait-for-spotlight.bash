#!/bin/bash -euo pipefail

# Power assertions indicate activity, not guaranteed index completeness.
# Require a sustained quiet period rather than accepting one released task.
function main() {
	local -r timeout=900
	local -r quiet_seconds=60
	local -r poll_interval=5
	local quiet_since=-1
	local saw_activity=false
	local assertions active

	SECONDS=0
	echo "Waiting for Spotlight metadata assertions to stay absent for ${quiet_seconds}s (timeout: ${timeout}s)."

	while ((SECONDS < timeout)); do
		if ! assertions=$(pmset -g assertions); then
			echo "Could not read power assertions; cannot determine Spotlight activity." >&2
			return 1
		fi
		active=$(printf '%s\n' "$assertions" | grep -E 'com\.apple\.metadata\.(mds|mds_stores)(\.power)?"' || true)

		if [[ -n "$active" ]]; then
			saw_activity=true
			quiet_since=-1
			echo "[${SECONDS}s] Spotlight assertions active; resetting quiet period:"
			printf '%s\n' "$active"
		else
			if ((quiet_since < 0)); then
				quiet_since=$SECONDS
			fi
			echo "[${SECONDS}s] No Spotlight metadata assertions; quiet for $((SECONDS - quiet_since))/${quiet_seconds}s."
			if ((SECONDS - quiet_since >= quiet_seconds)); then
				if [[ "$saw_activity" == false ]]; then
					echo "No matching activity was observed during this check; an indexing-to-idle transition was not verified."
				fi
				echo "Spotlight appears idle based on power assertions; this does not prove the index is complete."
				return 0
			fi
		fi

		sleep "$poll_interval"
	done

	echo "Timed out waiting for Spotlight to settle after ${timeout}s." >&2
	return 1
}

main "$@"
