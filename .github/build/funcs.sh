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

# Remove dir
remove_dir() {
    if [ -d "$1" ]; then
        rm -rf "$1"
    fi
}

# Get latest tag version
get_current_repo_tag() {
    cd "$root_prod" || exit 1
    tg=$(git rev-list --tags --max-count=1)
    ds=$(git describe --tags "$tg")
    echo "$ds" | sed 's/v//'
}

get_module_version() {
    local root_prod="$1"
    local version=""
    
    # Check if module.info exists and extract version
    if [ -f "module.info" ]; then
        version=$(grep -E '^version=[0-9]+(\.[0-9]+)*' module.info | head -n 1 | cut -d'=' -f2)
        version=$(echo "$version" | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/')
    fi

    # Fallback to get_current_repo_tag if no version found
    if [ -z "$version" ]; then
        version=$(get_current_repo_tag)
    fi
    
    # Return version (assumes version is always found)
    echo "$version"
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

# Make module repo
make_module_repo_cmd() {
    local module="$1"
    printf "git clone --depth 1 https://%s@github.com/virtualmin/%s.git %s" \
        "$github_token" "$module" "$verbosity_level"
}

# Get last commit date from repo
get_last_commit_date() {
    local repo_dir="$1"
    (
        cd "$repo_dir" || return 1
        git log -n1 --pretty='format:%cd' --date=format:'%Y%m%d%H%M'
    )
}

# Get required build scripts from Webmin repo
make_module_build_deps() {
    # Create directory for build dependencies if it doesn't exist
    if [ ! -d "$root/build-deps" ]; then
        mkdir -p "$root/build-deps"
    fi

    # Download required scripts from Webmin repo if they don't exist
    if [ ! -f "$root/build-deps/makemoduledeb.pl" ] || \
       [ ! -f "$root/build-deps/makemodulerpm.pl" ] || \
       [ ! -f "$root/build-deps/create-module.pl" ]; then
        echo "Downloading build dependencies .."
        
        # Create temporary directory
        local temp_dir=$(mktemp -d)
        cd "$temp_dir" || exit 1
        
        # Clone Webmin repository (minimal depth)
        cmd="git clone --depth 1 --filter=blob:none --sparse https://github.com/webmin/webmin.git $verbosity_level"
        eval "$cmd"
        postcmd $?
        echo
        
        cd webmin || exit 1
        
        # Copy required files to build-deps directory
        cp makemoduledeb.pl makemodulerpm.pl create-module.pl "$root/build-deps/"
        
        # Make scripts executable
        chmod +x "$root/build-deps/"*.pl
        
        # Clean up
        cd "$root" || exit 1
        remove_dir "$temp_dir"
    fi
}

# Adjust module filename depending on package type
adjust_module_filename() {
    local repo_dir="$1"
    local package_type="$2"
    local failed=0

    # Create a secure temporary file
    temp_file=$(mktemp) || { echo "Failed to create temporary file"; return 1; }

    # Find and adjust files based on the package type
    case "$package_type" in
    rpm)
        find "$repo_dir" -type f -name "*.rpm" > "$temp_file"
        ;;
    deb)
        find "$repo_dir" -type f -name "*.deb" > "$temp_file"
        ;;
    esac

    while read -r file; do
        base_name=$(basename "$file")
        dir_name=$(dirname "$file")
        local new_name

        case "$package_type" in
        rpm)
            # Handle RPM logic
            if [[ "$base_name" == webmin-* ]]; then
                new_name="${base_name/webmin-/wbm-}"
            elif [[ "$base_name" != wbm-* ]]; then
                new_name="wbm-$base_name"
            else
                continue
            fi
            ;;
        deb)
            # Handle DEB logic
            if [[ "$base_name" != webmin-* ]]; then
                new_name="webmin-$base_name"
            else
                continue
            fi
            ;;
        esac

        # Perform rename and check for failure
        if ! eval "mv \"$file\" \"$dir_name/$new_name\" $verbosity_level_with_input"; then
            failed=1
        fi
    done < "$temp_file"

    # Clean up the temporary file
    rm -f "$temp_file"

    # Return success or failure
    return $failed
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
