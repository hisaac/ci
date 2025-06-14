#!/bin/bash -euo pipefail

# This is based off of https://github.com/freegeek-pdx/mkuser
# Specifically: https://github.com/freegeek-pdx/mkuser/blob/b7a7900d2e6ef01dfafad1ba085c94f7302677d9/mkuser.sh#L6460-L6631
function main() {
	local -r username="${1:-${USERNAME}}"
	local -r password="${2:-${PASSWORD}}"

	echo "Enabling auto-login for ${username}..."

	# These are the special "kcpassword" repeating cipher hex characters.
	local -ra cipher_key=( '7d' '89' '52' '23' 'd2' 'bc' 'dd' 'ea' 'a3' 'b9' '1f' )
	local -ri cipher_key_length="${#cipher_key[@]}"

	local encoded_password_hex_string
	local -i this_password_hex_char_index=0
	while IFS='' read -r this_password_hex_char; do
		printf -v this_encoded_password_hex_char '%02x' "$(( 0x${this_password_hex_char} ^ 0x${cipher_key[this_password_hex_char_index % cipher_key_length]} ))"
		encoded_password_hex_string+="${this_encoded_password_hex_char} "
		this_password_hex_char_index+=1
	done < <(printf '%s' "${password}" | xxd -c 1 -p)

	encoded_password_hex_string="${cipher_key[this_password_hex_char_index % cipher_key_length]}"

	sudo rm -rf '/private/etc/kcpassword'
	sudo touch '/private/etc/kcpassword'
	sudo chown 0:0 '/private/etc/kcpassword'
	sudo chmod 600 '/private/etc/kcpassword'

	echo "${encoded_password_hex_string}" | xxd -r -p | sudo tee '/private/etc/kcpassword' > /dev/null

	if [[ ! -f '/private/etc/kcpassword' ]] || ! encoded_password_length="$(sudo wc -c '/private/etc/kcpassword' 2> /dev/null | awk '{ print $1; exit }')" || (( encoded_password_length == 0 )); then
		echo "Failed to set auto login password"
		exit 1
	fi

	encoded_password_random_data_padding_multiples="$(( cipher_key_length + 1 ))"
	if (( (encoded_password_length % encoded_password_random_data_padding_multiples) != 0 )); then
		head -c "$(( encoded_password_random_data_padding_multiples - (encoded_password_length % encoded_password_random_data_padding_multiples) ))" /dev/urandom | sudo tee -a '/private/etc/kcpassword' > /dev/null
	fi

	sudo defaults write '/Library/Preferences/com.apple.loginwindow' autoLoginUser -string "${username}"
}

main "$@"
