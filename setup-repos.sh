#!/bin/sh
# setup-repos.sh — suppressed by webmin-setup-repo.sh
# Sets up a production or testing repository for Webmin and Usermin packages
# on Debian-based and RPM-based systems

NEW_SCRIPT_URL="https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh"

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
