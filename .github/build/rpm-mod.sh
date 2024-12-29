#!/usr/bin/env bash
#
# Automatically builds and updates repo metadata for Webmin modules.
# Pulls latest changes from GitHub, detects release version based 
# on what's available in the repo.
#
#                    (RPM)
#
# Usage:
#   # Build all modules with production versions
#      ./rpm-mod.sh
#
#   # Build all modules with development versions and debug
#      ./rpm-mod.sh --testing --debug
#
#   # Build specific module with version and release
#      ./rpm-mod.sh virtualmin-nginx 2.36 3
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
    local epoch
    local devel=0
    local root_module="$root/$module"

    # Print build actual date
    date=$(get_current_date)

    # Print opening header
    echo "************************************************************************"
    echo "        build start date: $date                                         "
    echo "          package format: RPM                                           "
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
    else
        rel=1
    fi
    if [[ "'$4'" != *"--"* ]] && [[ -n "$4" ]]; then
        epoch="--epoch $4"
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
    make_dir "$root/newkey/rpm/"
    make_dir "$root/umodules/"
    make_dir "$root/minimal/"
    make_dir "$root/tarballs/"
    make_dir "$root_build/BUILD/"
    make_dir "$root_build/BUILDROOT/"
    make_dir "$root_build/RPMS/"
    make_dir "$root_rpms"
    make_dir "$root_build/SOURCES/"
    make_dir "$root_build/SPECS/"
    make_dir "$root_build/SRPMS/"
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

    # Build RPM package
    echo "Building packages.."
    (
        # XXXX Update actual module testing version dynamically
        cd "$root" || exit 1
        cmd="$root/build-deps/makemodulerpm.pl $epoch--release $rel --rpm-depends --licence 'GPLv3' --allow-overwrite --rpm-dir $root_build --target-dir $root_module/tmp $module $verbosity_level"
        eval "$cmd"
        postcmd $?
    )

    echo
    echo "Preparing built files for upload .."
    # Move RPM to repos
    cmd="find $root_rpms -name wbm-$module*$verorig*\.rpm -exec mv '{}' $root_repos \; $verbosity_level"
    eval "$cmd"
    if [ "$devel" -eq 1 ]; then
        cmd="mv -f $root_repos/wbm-$module*$verorig*\.rpm $root_repos/${module}-$ver-$rel.noarch.rpm $verbosity_level"
        eval "$cmd"
    fi
    postcmd $?
    echo

    # Adjust module filename
    echo "Adjusting module filename .."
    adjust_module_filename "$root_repos" "rpm"
    postcmd $?
    echo

    echo "Post-clean up .."
    remove_dir "$root_module"
    # Purge old files
    purge_dir "$root_prod/newkey/rpm"
    purge_dir "$root_prod/umodules"
    purge_dir "$root_prod/minimal"
    purge_dir "$root_prod/tarballs"
    purge_dir "$root_build/BUILD"
    purge_dir "$root_build/BUILDROOT"
    purge_dir "$root_build/RPMS"
    purge_dir "$root_build/SOURCES"
    purge_dir "$root_build/SPECS"
    purge_dir "$root_build/SRPMS"
    remove_dir "$root_repos/repodata"
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
