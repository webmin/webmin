#!/usr/bin/env bash
#
# Automatically builds and updates repo metadata for Webmin modules.
# Pulls latest changes from GitHub, detects release version based 
# on what's available in the repo.
#
#                    (DEB)
#
# Usage:
#   # Build all modules with production versions
#      ./deb-mod.sh
#
#   # Build all modules with development versions and debug
#      ./deb-mod.sh --testing --debug
#
#   # Build specific module with version and release
#      ./deb-mod.sh virtualmin-nginx 2.36 2
#

# shellcheck disable=SC1091
# Source build variables
source ./vars.sh || exit 1

# Source build init
source ./init.sh || exit 1

# Source general build functions
source ./funcs.sh || exit 1

# Build module func
build_module() {
    # Always return back to root directory
    cd "$root" || exit 1

    # Define variables
    local last_commit_date
    local ver=""
    local verorig=""
    local module=$1
    local rel
    local relval
    local devel=0
    local root_module="$root/$module"

    # Print build actual date
    date=$(get_current_date)

    # Print opening header
    echo "************************************************************************"
    echo "        build start date: $date                                         "
    echo "          package format: DEB                                           "
    echo "                  module: $module                                       "

    # Pull or clone module repository
    remove_dir "$root_module"
    cmd=$(make_module_repo_cmd "$module")
    eval "$cmd"
    rs=$?

    # Git last commit date
    last_commit_date=$(get_last_commit_date "$root_module")

    # Handle other params
    cd "$root_module" || exit 1
    if [[ "'$2'" != *"--"* ]]; then
        ver=$2
    fi
    if [[ "'$3'" != *"--"* ]] && [[ -n "$3" ]]; then
        rel=$3
        relval="-$3"
    else
        rel=1
        relval=""
    fi
    if [ -z "$ver" ]; then
        ver=$(get_module_version)
    fi
    if [[ "'$*'" == *"--testing"* ]]; then
        devel=1
        verorig=$ver
        ver=$(echo "$ver" | cut -d. -f1,2)
        ver="$ver.$last_commit_date"
    fi

    echo "  package output version: $ver-$rel"
    echo "************************************************************************"

    echo "Pulling latest changes.."
    postcmd $rs
    echo

    echo "Pre-clean up .."
    # Make sure directories exist
    make_dir "$root_module/tmp"
    make_dir "$root_repos"

    # Purge old files
    purge_dir "$root_module/tmp"
    if [ "$module" != "" ]; then
        rm -f "$root_repos/$module-latest"*
    fi
    postcmd $?
    echo

    # Download required build dependencies
    make_module_build_deps
    
    # Build DEB package
    echo "Building packages .."
    (
        # XXXX Update actual module testing version dynamically
        cd "$root" || exit 1
        cmd="$root/build-deps/makemoduledeb.pl --release $rel --deb-depends --licence 'GPLv3' --email 'ilia@virtualmin.dev' --allow-overwrite --target-dir $root_module/tmp $module $verbosity_level"
        eval "$cmd"
        postcmd $?
    )

    echo
    echo "Preparing built files for upload .."
    # Move DEB to repos
    cmd="find $root_module/tmp -name webmin-${module}*$verorig*\.deb -exec mv '{}' $root_repos \; $verbosity_level"
    eval "$cmd"
    if [ "$devel" -eq 1 ]; then
        cmd="mv -f $root_repos/*${module}*$verorig*\.deb $root_repos/${module}_${ver}-1_all.deb $verbosity_level"
        eval "$cmd"
    fi
    postcmd $?
    echo
    
    # Adjust module filename
    echo "Adjusting module filename .."
    adjust_module_filename "$root_repos" "deb"
    postcmd $?
    echo

    echo "Post-clean up .."
    remove_dir "$root_module"
    postcmd $?
}

# Main
if [ -n "$1" ] && [[ "'$1'" != *"--"* ]]; then
    build_module $@
    cloud_upload_list_upload=("$root_repos/*$1*")
else
    for module in "${webmin_modules[@]}"; do
        build_module $module $@
    done
    cloud_upload_list_upload=("$root_repos/*")
fi

cloud_upload cloud_upload_list_upload
cloud_repo_sign_and_update
