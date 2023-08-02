#!/usr/bin/env bash
#
# Copyright @iliajie <ilia@webmin.dev>
#
# Automatically builds and updates a repo metadata.
# Pulls latest changes from GitHub, detects release
# version based on what's available in the repo
#
#                    (RHEL)
#
# Usage:
#
#   # Pull and build production versions
#   # of both Webmin and Usermin
#      ./rpm.sh
#
#   # Pull and build devel versions
#   # of both Webmin and Usermin
#      ./rpm.sh --devel
#
#   # Pull and build production Webmin version 2.101, forcing
#   # release version 3, displaying detailed output
#      ./rpm.sh webmin 2.101 3 --debug
#
#   # Pull and build production Usermin version 2.000,
#   # automatically setting release version to minimal
#      ./rpm.sh usermin 2.000
#

# shellcheck disable=SC1091
# Source build variables
source ./vars.sh || exit 1

# Source build init
source ./init.sh || exit 1

# Source general build functions
source ./funcs.sh || exit 1

# Build product func
build_prod() {

    # Pack with English only in devel builds
    local english_only=0
    if [[ "'$*'" == *"--devel"* ]]; then
        english_only=1
    fi

    # Always return back to root directory
    cd "$root" || exit 1

    # Define root
    local ver=""
    local prod=$1
    root_prod="$root/$prod"

    # Print build actual date
    date=$(get_current_date)

    # Print opening header
    echo "************************************************************************"
    echo "        build start date: $date                                         "
    echo "          package format: RPM                                           "
    echo "                 product: $prod                                         "
    (make_prod_repos "$root_prod") &
    spinner "  package output version:"

    # Pull main project first to get the latest tag
    cd "$root_prod" || exit 1
    cmd="git pull $verbosity_level"
    eval "$cmd"
    rs1=$?
    # Clean and try again
    if [ "$rs1" != "0" ]; then
        cmd="git checkout \"*\" $verbosity_level && git clean -f -d $verbosity_level && git pull $verbosity_level"
        eval "$cmd"
        rs1=$?
    fi

    # Pull theme to theme dir
    cd "authentic-theme" || exit 1
    cmd="git pull $verbosity_level"
    eval "$cmd"
    rs2=$?
    # Clean and try again
    if [ "$rs2" != "0" ]; then
        cmd="git checkout \"*\" $verbosity_level && git clean -f -d $verbosity_level && git pull $verbosity_level"
        eval "$cmd"
        rs2=$?
    fi
    if [ "$rs1" != "0" ] || [ "$rs2" != "0" ]; then
        rs=1
    else
        rs=0
    fi
    
    # Build number
    date_version=$(get_latest_commit_date_version)

    # Handle other params
    cd "$root_prod" || exit 1
    if [[ "'$2'" != *"--"* ]]; then
        ver=$2
    fi
    if [[ "'$3'" != *"--"* ]] && [[ -n "$3" ]]; then
        rel=$3
    else
        rel=1
    fi
    if [ -z "$ver" ]; then
        ver=$(get_current_repo_tag)
    fi
    if [[ "'$*'" == *"--devel"* ]]; then
        ver="$ver.$date_version"
        # Set actual product version
        echo "${ver}" >"version"
    fi

    printf "$ver-$rel\n"
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
    make_dir "$root_build/BUILD/"
    make_dir "$root_build/BUILDROOT/"
    make_dir "$root_build/RPMS/"
    make_dir "$root_build/SOURCES/"
    make_dir "$root_build/SPECS/"
    make_dir "$root_build/SRPMS/"
    make_dir "$root_repos/"

    # Re-create legacy link
    rm -rf "$root/webadmin"
    ln -s "$root/webmin" "$root/webadmin"

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
    rm -rf "$root_repos/repodata"
    if [ "$prod" != "" ]; then
        # XXXX Need to check for
        # product name exactly
        rm -f "$root_repos/$prod-latest"*
    fi
    postcmd $?
    make_dir "$root_build/RPMS/noarch"
    echo

    # Descend to project dir
    cd "$root_prod" || exit 1
    
    if [ "$english_only" = "1" ]; then
        echo "Cleaning languages .."
        cmd="./bin/language-manager --mode=clean --yes $verbosity_level_with_input"
        eval "$cmd"
        postcmd $?
        echo
    else
        # Force restore build directory
        if [ ! -f "lang/ja" ]; then
            echo "Restoring languages .."
            cmd="git checkout \"*\" $verbosity_level && git clean -f -d $verbosity_level && git pull $verbosity_level"
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

    cmd="./makedist.pl \"$args\" $verbosity_level"
    eval "$cmd"
    postcmd $?
    echo

    echo "Building package .."
    cmd="./makerpm.pl \"$ver\" \"$rel\" $verbosity_level"
    eval "$cmd"
    postcmd $?
    echo

    cd "$root" || exit 1
    echo "Preparing built files for upload .."
    cmd="cp -f $root_prod/tarballs/$prod-$ver*\.tar.gz $root_repos/${prod}-latest.tar.gz $verbosity_level"
    eval "$cmd"
    cmd="echo $ver-$rel \($date\) > $root_repos/$prod-latest.version"
    eval "$cmd"
    cmd="find $root_rpms -name $prod-$ver-$rel*\.rpm -exec mv '{}' $root_repos \; $verbosity_level"
    eval "$cmd"
    cmd="mv -f $root_repos/$prod-$ver-$rel*\.rpm $root_repos/${prod}-latest.rpm $verbosity_level"
    eval "$cmd"
    postcmd $?
    echo

    echo "Post-clean up .."
    cd "$root_build" || exit 1
    for dir in *; do
        cmd="rm -rf \"$dir/*\" $verbosity_level"
        eval "$cmd"
    done
    postcmd $?
}

if [ -n "$1" ] && [[ "'$1'" != *"--"* ]]; then
    build_prod $@
    
    cloud_upload_list_upload=("$root_repos/$1*")
    cloud_upload cloud_upload_list_upload
    
    cloud_repo_sign_and_update

else
    build_prod webmin $@
    build_prod usermin $@

    cloud_upload_list_upload=("$root_repos/*")
    cloud_upload cloud_upload_list_upload
    
    cloud_repo_sign_and_update
fi
