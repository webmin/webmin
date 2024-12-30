#!/usr/bin/env bash
# shellcheck disable=SC2034
# build-rpm-module.bash
# Copyright Ilia Ross <ilia@webmin.dev>
#
# Automatically builds DEB Webmin module pulls changes from GitHub, creates
# testing builds from the latest code with English-only support, production
# builds from the latest tag, uploads them to the pre-configured repository,
# updates the repository metadata, and interacts with the environment using
# bootstrap
#
# Usage:
#
#   Build testing module with in verbose mode
#     ./build-rpm-module.bash virtualmin-nginx --testing --verbose
#
#   Build specific module with version and release
#     ./build-rpm-module.bash virtualmin-nginx 2.36 2
#

# shellcheck disable=SC1091
# Bootstrap build environment
source ./bootstrap.bash || exit 1

# Build module func
build_module() {
    # Always return back to root directory
    cd "$ROOT_DIR" || exit 1

    # Define variables
    local last_commit_date
    local ver=""
    local verorig=""
    local module=$1
    local rel
    local epoch
    local devel=0
    local root_module="$ROOT_DIR/$module"

    # Print build actual date
    date=$(get_current_date)

    # Print opening header
    echo "************************************************************************"
    echo "        build start date: $date                                         "
    echo "          package format: RPM                                           "
    echo "                  module: $module                                       "

    # Pull or clone module repository
    remove_dir "$root_module"
    cmd=$(make_module_repo_cmd "$module" "$MODULES_REPO_URL")
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
    make_dir "$ROOT_DIR/newkey/rpm/"
    make_dir "$ROOT_DIR/umodules/"
    make_dir "$ROOT_DIR/minimal/"
    make_dir "$ROOT_DIR/tarballs/"
    make_dir "$ROOT_BUILD/BUILD/"
    make_dir "$ROOT_BUILD/BUILDROOT/"
    make_dir "$ROOT_BUILD/RPMS/"
    make_dir "$ROOT_RPMS"
    make_dir "$ROOT_BUILD/SOURCES/"
    make_dir "$ROOT_BUILD/SPECS/"
    make_dir "$ROOT_BUILD/SRPMS/"
    make_dir "$ROOT_REPOS"

    # Purge old files
    purge_dir "$root_module/tmp"
    if [ "$module" != "" ]; then
        rm -f "$ROOT_REPOS/$module-latest"*
    fi
    postcmd $?
    echo

    # Download required build dependencies
    make_module_build_deps

    # Build RPM package
    echo "Building packages.."
    (
        # XXXX Update actual module testing version dynamically
        cd "$ROOT_DIR" || exit 1
        cmd="$ROOT_DIR/build-deps/makemodulerpm.pl $epoch--release \
            $rel --rpm-depends --licence 'GPLv3' --allow-overwrite --rpm-dir \
            $ROOT_BUILD --target-dir $root_module/tmp $module $VERBOSITY_LEVEL"
        eval "$cmd"
        postcmd $?
    )

    echo
    echo "Preparing built files for upload .."
    # Move RPM to repos
    cmd="find $ROOT_RPMS -name wbm-$module*$verorig*\.rpm -exec mv '{}' \
        $ROOT_REPOS \; $VERBOSITY_LEVEL"
    eval "$cmd"
    if [ "$devel" -eq 1 ]; then
        cmd="mv -f $ROOT_REPOS/wbm-$module*$verorig*\.rpm \
            $ROOT_REPOS/${module}-$ver-$rel.noarch.rpm $VERBOSITY_LEVEL"
        eval "$cmd"
    fi
    postcmd $?
    echo

    # Adjust module filename
    echo "Adjusting module filename .."
    adjust_module_filename "$ROOT_REPOS" "rpm"
    postcmd $?
    echo

    echo "Post-clean up .."
    remove_dir "$root_module"
    # Purge old files
    purge_dir "$ROOT_BUILD/BUILD"
    purge_dir "$ROOT_BUILD/BUILDROOT"
    purge_dir "$ROOT_BUILD/RPMS"
    purge_dir "$ROOT_BUILD/SOURCES"
    purge_dir "$ROOT_BUILD/SPECS"
    purge_dir "$ROOT_BUILD/SRPMS"
    remove_dir "$ROOT_REPOS/repodata"
    postcmd $?
}

# Main
if [ -n "$1" ] && [[ "'$1'" != *"--"* ]]; then
    MODULES_REPO_URL="$VIRTUALMIN_ORG_AUTH_URL"
    build_module "$@"
    cloud_upload_list_upload=("$ROOT_REPOS/*$1*")
    cloud_upload cloud_upload_list_upload
    cloud_repo_sign_and_update
else
    # Error otherwise
    echo "Error: No module specified"
    exit 1
fi
