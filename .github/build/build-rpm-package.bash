#!/usr/bin/env bash
# shellcheck disable=SC2034
# build-rpm-package.bash
# Copyright Ilia Ross <ilia@webmin.dev>
#
# Automatically builds RPM packages of Webmin and Usermin with the latest
# Authentic Theme, pulls changes from GitHub, creates testing builds from the
# latest code with English-only support, production builds from the latest tag,
# uploads them to the pre-configured repository, updates the repository
# metadata, and interacts with the environment using bootstrap
#
# Usage:
#
#   Pull and build production versions of both Webmin and Usermin
#     ./build-rpm-package.bash
#
#   Pull and build testing versions of both Webmin and Usermin
#     ./build-rpm-package.bash --testing
#
#   Pull and build production Webmin version 2.101, forcing
#   release version 3, displaying verbose output
#     ./build-rpm-package.bash webmin 2.101 3 --testing
#
#   Pull and build production Usermin version 2.000,
#   automatically setting release version
#     ./build-rpm-package.bash usermin 2.000
#

# shellcheck disable=SC1091
# Bootstrap build environment
source ./bootstrap.bash || exit 1

# Build product func
build_prod() {

    # Pack with English only in devel builds
    local english_only=0
    if [[ "'$*'" == *"--testing"* ]]; then
        english_only=1
    fi

    # Always return back to root directory
    cd "$ROOT_DIR" || exit 1

    # Define root
    local ver=""
    local prod=$1
    local devel=0
    local root_prod="$ROOT_DIR/$prod"

    # Print build actual date
    date=$(get_current_date)

    # Print opening header
    echo "************************************************************************"
    echo "        build start date: $date                                         "
    echo "          package format: RPM                                           "
    echo "                 product: $prod                                         "
    echo -n "    downloading packages: "
    
    # Download products from repos
    make_packages_repos "$root_prod" "$prod"
    local rs=$? # Store to print success or failure nicely later
    if [ $rs -eq 0 ]; then
        echo -e "✔"
    else
        echo -e "✘"
    fi
    
    # Print package version
    echo -n "         package version: "
    
    # Get latest product version (theme vs product); expects to start in theme
    # repo and switch to product repo internally
    date_version=$(get_latest_commit_date_version "$root_prod")

    # Handle other params
    if [[ "'$2'" != *"--"* ]]; then
        ver=$2
    fi
    if [[ "'$3'" != *"--"* ]] && [[ -n "$3" ]]; then
        rel=$3
    else
        rel=1
    fi
    if [ -z "$ver" ]; then
        ver=$(get_current_repo_tag "$root_prod")
    fi
    if [[ "'$*'" == *"--testing"* ]]; then
        devel=1
        ver="$ver.$date_version"
        # Set actual product version
        echo "${ver}" >"version"
    fi

    printf "%s-%s\n" "$ver" "$rel"
    echo "************************************************************************"

    echo "Pulling latest changes.."
    # We need to pull first to get the latest tag,
    # so here we only report an error if any
    postcmd $rs
    echo

    echo "Pre-clean up .."
    # Make sure directories exist
    make_dir "$root_prod/newkey/rpm/"
    make_dir "$root_prod/umodules/"
    make_dir "$root_prod/minimal/"
    make_dir "$root_prod/tarballs/"
    make_dir "$ROOT_BUILD/BUILD/"
    make_dir "$ROOT_BUILD/BUILDROOT/"
    make_dir "$ROOT_BUILD/RPMS/"
    make_dir "$ROOT_BUILD/SOURCES/"
    make_dir "$ROOT_BUILD/SPECS/"
    make_dir "$ROOT_BUILD/SRPMS/"
    make_dir "$ROOT_REPOS/"

    # Re-create legacy link
    remove_dir "$ROOT_DIR/webadmin"
    ln -s "$ROOT_DIR/webmin" "$ROOT_DIR/webadmin"

    # Purge old files
    purge_dir "$root_prod/newkey/rpm"
    purge_dir "$root_prod/umodules"
    purge_dir "$root_prod/minimal"
    purge_dir "$root_prod/tarballs"
    purge_dir "$ROOT_BUILD/BUILD"
    purge_dir "$ROOT_BUILD/BUILDROOT"
    purge_dir "$ROOT_BUILD/RPMS"
    purge_dir "$ROOT_BUILD/SOURCES"
    purge_dir "$ROOT_BUILD/SPECS"
    purge_dir "$ROOT_BUILD/SRPMS"
    remove_dir "$ROOT_REPOS/repodata"
    if [ "$prod" != "" ]; then
        rm -f "$ROOT_REPOS/$prod-"*
        rm -f "$ROOT_REPOS/${prod}_"*
    fi
    postcmd $?
    make_dir "$ROOT_BUILD/RPMS/noarch"
    echo

    # Descend to project dir
    cd "$root_prod" || exit 1
    
    if [ "$english_only" = "1" ]; then
        echo "Cleaning languages .."
        cmd="./bin/language-manager --mode=clean --yes \
            $VERBOSITY_LEVEL_WITH_INPUT"
        eval "$cmd"
        postcmd $?
        echo
    else
        # Force restore build directory
        if [ ! -f "lang/ja" ]; then
            echo "Restoring languages .."
            cmd="git checkout \"*\" $VERBOSITY_LEVEL && git clean -f -d \
                $VERBOSITY_LEVEL && git pull $VERBOSITY_LEVEL"
            eval "$cmd"
            postcmd $?
            echo
        fi
    fi
    echo "Pre-building package .."
    eval "$cmd"
    if [ "$rel" = "1" ]; then
        args="$ver"
    else
        args="$ver-$rel"
    fi

    cmd="./makedist.pl \"$args\" $VERBOSITY_LEVEL"
    eval "$cmd"
    postcmd $?
    echo

    echo "Building package .."
    cmd="./makerpm.pl \"$ver\" \"$rel\" $VERBOSITY_LEVEL"
    eval "$cmd"
    postcmd $?
    echo

    cd "$ROOT_DIR" || exit 1
    echo "Preparing built files for upload .."
    cmd="cp -f $root_prod/tarballs/$prod-$ver*\.tar.gz \
        $ROOT_REPOS/${prod}-$ver.tar.gz $VERBOSITY_LEVEL"
    eval "$cmd"
    cmd="find $ROOT_RPMS -name $prod-$ver-$rel*\.rpm -exec mv '{}' \
        $ROOT_REPOS \; $VERBOSITY_LEVEL"
    eval "$cmd"
    # cmd="mv -f $ROOT_REPOS/$prod-$ver-$rel*\.rpm \
    #   $ROOT_REPOS/${prod}-$ver-$rel.noarch.rpm $VERBOSITY_LEVEL" # file name is already always the same
    # eval "$cmd"
    postcmd $?
    echo

    echo "Post-clean up .."
    cd "$ROOT_BUILD" || exit 1
    for dir in *; do
        cmd="rm -rf \"$dir/*\" $VERBOSITY_LEVEL"
        eval "$cmd"
    done
    postcmd $?
}

# Main
if [ -n "$1" ] && [[ "$1" != --* ]]; then
    build_prod "$@"
    cloud_upload_list_upload=("$ROOT_REPOS/$1*")
else
    build_prod webmin "$@"
    build_prod usermin "$@"
    cloud_upload_list_upload=("$ROOT_REPOS/"*)
fi

cloud_upload cloud_upload_list_upload
cloud_repo_sign_and_update
