#!/bin/sh
# webmin-setup-repos.sh — suppressed by webmin-setup-repo.sh
# Sets up a production or testing repository for Webmin and Usermin packages
# on Debian-based and RPM-based systems

URL_BASE="https://raw.githubusercontent.com"
URL_PATH="/webmin/webmin/master/webmin-setup-repo.sh"
NEW_SCRIPT_URL="${URL_BASE}${URL_PATH}"

for downloader in "curl -fsSL" "wget -qO-"; do
	if command -v "${downloader%% *}" >/dev/null 2>&1; then
		tmp_script=$(mktemp)
		case $downloader in
			curl*) curl -fsSL "$NEW_SCRIPT_URL" > "$tmp_script" ;;
			wget*) wget -qO- "$NEW_SCRIPT_URL" > "$tmp_script" ;;
		esac
		sh "$tmp_script" "$@"
		rm -f "$tmp_script"
		exit 0
	fi
done

# If neither downloader works, show an error
echo "Error: Neither curl nor wget is installed." >&2
exit 1
