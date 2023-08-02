#!/usr/bin/env bash
#
# Copyright @iliajie <ilia@webmin.dev>
#
# Automatically builds and updates a repo metadata.
# Pulls latest changes from GitHub, detects release
# version based on what's available in the repo
#
#                  (Debian)
#
# Usage:
#
#   # Pull and build production versions
#   # of both Webmin and Usermin
#      ./deb.sh
#
#   # Pull and build devel versions
#   # of both Webmin and Usermin
#      ./deb.sh --devel
#
#   # Pull and build production Webmin version 2.101, forcing
#   # release version 3, displaying detailed output
#      ./deb.sh webmin 2.101 3 --debug
#
#   # Pull and build production Usermin version 2.000,
#   # automatically setting release version to minimal
#      ./deb.sh usermin 2.000
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
    root_apt="$root_prod/deb"

    # Print build actual date
    date=$(get_current_date)

    # Print opening header
    echo "************************************************************************"
    echo "        build start date: $date                                         "
    echo "          package format: DEB                                           "
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

    # Descend to theme dir
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
        relval="-$3"
    else
        rel=1
        relval=""
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
    make_dir "$root_repos/"
    make_dir "$root_apt/"
    make_dir "$root_prod/newkey/deb/"
    make_dir "$root_prod/umodules/"
    make_dir "$root_prod/minimal/"
    make_dir "$root_prod/tarballs/"

    # Re-create legacy link
    rm -rf "$root/webadmin"
    ln -s "$root/webmin" "$root/webadmin"

    # Purge old files
    purge_dir "$root_prod/newkey/deb"
    purge_dir "$root_prod/umodules"
    purge_dir "$root_prod/minimal"
    purge_dir "$root_prod/tarballs"
    if [ "$prod" != "" ]; then
        # XXXX Need to check for
        # product name exactly
        rm -f "$root_repos/$prod-latest"*
    fi
    postcmd $?
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
    cmd="./makedist.pl \"${ver}${relval}\" $verbosity_level"
    eval "$cmd"
    postcmd $?
    echo

    echo "Building package .."
    if [ "$relval" == "" ]; then
        cmd="./makedebian.pl \"$ver\" $verbosity_level"
    else
        cmd="./makedebian.pl \"$ver\" \"$rel\" $verbosity_level"
    fi
    eval "$cmd"
    postcmd $?
    echo

    cd "$root" || exit 1
    echo "Preparing built files for upload .."
    cmd="cp -f $root_prod/tarballs/${prod}-${ver}*\.tar.gz $root_repos/${prod}-latest.tar.gz $verbosity_level"
    eval "$cmd"
    cmd="echo $ver-$rel \($date\) > $root_repos/${prod}-latest.version $verbosity_level_to_file"
    eval "$cmd"
    cmd="find $root_apt -name ${prod}_${ver}${relval}*\.deb -exec mv '{}' $root_repos \; $verbosity_level"
    eval "$cmd"
    cmd="mv -f $root_repos/${prod}_${ver}${relval}*\.deb $root_repos/${prod}-latest.deb $verbosity_level"
    eval "$cmd"
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
