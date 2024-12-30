#!/usr/bin/env bash
# shellcheck disable=SC1091
# bootstrap.bash
# Copyright Ilia Ross <ilia@webmin.dev>
# Bootstrap the build process

# Bootstrap URL
BUILD_BOOTSTRAP_URL="https://raw.githubusercontent.com/webmin/webmin/master/.github/build"

# Bootstrap scripts
BOOTSTRAP_SCRIPTS=(
    "environment.bash"
    "functions.bash"
    "build-deb-module.bash"
    "build-deb-package.bash"
    "build-rpm-module.bash"
    "build-rpm-package.bash"
)

bootstrap() {
    local base_url="$BUILD_BOOTSTRAP_URL/"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    download_script() {
	local script_url="$1"
	local script_path="$2"
	for downloader in "curl -fsSL" "wget -qO-"; do
	    if command -v "${downloader%% *}" >/dev/null 2>&1; then
		if eval "$downloader \"$script_url\" > \"$script_path\""; then
		    chmod +x "$script_path"
		    return 0
		fi
	    fi
	done
	return 1
    }
    for script in "${BOOTSTRAP_SCRIPTS[@]}"; do
	local script_path="$script_dir/$script"
	if [ ! -f "$script_path" ]; then
	    if ! download_script "${base_url}${script}" "$script_path"; then
		echo "Error: Failed to download $script. Cannot continue."
		exit 1
	    fi
	fi
    done

    # Source general build functions
    source "$script_dir/functions.bash" || exit 1

    # Source build variables
    source "$script_dir/environment.bash" || exit 1
}

# Bootstrap build environment
bootstrap || exit 1
