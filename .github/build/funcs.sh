#!/usr/bin/env bash
#
# Copyright @iliajie <ilia@webmin.dev>
#
# General build functions
#
#

# Upload to cloud
# Usage:
#   cloud_upload_list_delete=("$cloud_upload_ssh_dir/repodata")
#   cloud_upload_list_upload=("$root_repos/*" "$root_repos/repodata")
#   cloud_upload cloud_upload_list_upload cloud_upload_list_delete
cloud_upload() {
    # Print new block only if definded
    local ssh_args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    if [ -n "$1" ]; then
        echo
    fi
    # Delete files on remote if needed
    if [ -n "$2" ]; then
        echo "Deleting given files in $cloud_upload_ssh_host .."
        local -n arr_del=$2
        local err=0
        for d in "${arr_del[@]}"; do
            if [ -n "$d" ]; then
                local cmd1="ssh $ssh_args $cloud_upload_ssh_user@$cloud_upload_ssh_host \"rm -rf $d\" $verbosity_level"
                eval "$cmd1"
                if [ "$?" != "0" ]; then
                    err=1
                fi
            fi
        done
        postcmd $err
        echo
    fi
    
    # Upload files to remote
    if [ -n "$1" ]; then
        echo "Uploading built files to $cloud_upload_ssh_host .."
        local -n arr_upl=$1
        local err=0
        for u in "${arr_upl[@]}"; do
            if [ -n "$u" ]; then
                local cmd2="scp $ssh_args -r $u $cloud_upload_ssh_user@$cloud_upload_ssh_host:$cloud_upload_ssh_dir/ $verbosity_level"
                eval "$cmd2"
                if [ "$?" != "0" ]; then
                    err=1
                fi
            fi
        done
        postcmd $err
        echo
    fi
}

# Sign and update repos metadata in remote
cloud_repo_sign_and_update() {
    echo "Signing and updating repos metadata in $cloud_upload_ssh_host .."
    local ssh_args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    local remote_cmd="cd ~/.scripts && ./update-repo-packages-signature.bash $cloud_upload_gpg_passphrase"
    local cmd1="ssh $ssh_args $cloud_upload_ssh_user@$cloud_upload_ssh_host \"$remote_cmd\" $verbosity_level"
    eval "$cmd1"
    postcmd $?
    echo
}

# Post command func
postcmd() {
    if [ "$1" != "0" ]; then
        echo ".. failed"
        exit 1
    else
        echo ".. done"
    fi
}

# Get max number from array
max() {
    local -n arr_nums=$1
    IFS=$'\n'
    echo "${arr_nums[*]}" | sort -nr | head -n1
}

# Mkdir and children dirs
make_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
    fi
}

# Remove all content in dir
purge_dir() {
    for file in "$1"/*; do
        rm -rf "$file"
    done
}

# Get latest tag version
get_current_repo_tag() {
    cd "$root_prod" || exit 1
    tg=$(git rev-list --tags --max-count=1)
    ds=$(git describe --tags "$tg")
    echo "$ds" | sed 's/v//'
}

# Get latest commit date
get_current_date() {
    echo $(date +'%Y-%m-%d %H:%M:%S %z')
}

# Get latest commit date version
get_latest_commit_date_version() {
    local theme_version
    local prod_version
    local max_prod
    local highest_version

    theme_version=$(git log -n1 --pretty='format:%cd' --date=format:'%Y%m%d%H%M')
    cd "$root_prod" || exit 1
    prod_version=$(git log -n1 --pretty='format:%cd' --date=format:'%Y%m%d%H%M')
    max_prod=("$theme_version" "$prod_version")
    highest_version=$(max max_prod)
    echo "$highest_version"
}

# Pull project repo and theme
make_prod_repos() {
    # Webmin or Usermin
    if [ ! -d "$1" ]; then
        local repo="webmin/$prod.git"
        cmd="git clone https://github.com/$repo $verbosity_level"
        eval "$cmd"
        if [ ! -d "webmin" ]; then
            cmd="git clone --depth 1 https://github.com/webmin/webmin $verbosity_level"
            eval "$cmd"
        fi
    fi
    # Theme
    theme="authentic-theme"
    if [ ! -d "$1/$theme" ]; then
        cd "$1" || exit 1
        local repo="webmin/$theme.git"
        cmd="git clone --depth 1 https://github.com/$repo $verbosity_level"
        eval "$cmd"
    fi
}

spinner() {
  local msg=$1
  local pid=$!
  local spin='-\|/'
  local i=0
  printf "$msg "
  while kill -0 $pid 2>/dev/null; do
    (( i = (i + 1) % 4 ))
    # No spinner if not an interactive shell
    if [ -n "$PS1" ]; then
        printf '%c\b' "${spin:i:1}"
    fi
    sleep .1
  done
}
