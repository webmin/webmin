#!/usr/bin/env bash
# functions.bash
# Copyright Ilia Ross <ilia@webmin.dev>
# Build functions for the build process

# Set up SSH keys on the build machine
setup_ssh() {
    local key_path="$HOME/.ssh/id_rsa"

    # If SSH keys are already set up, skip this step
    if [ -f "$key_path" ] && [ -f "$key_path.pub" ]; then
        return 0
    fi

    # Use SSH command to generate new pair and take care of permissions
    cmd="ssh-keygen -t rsa -q -f \"$key_path\" \
        -N \"\" <<< \"y\"$VERBOSITY_LEVEL"
    eval "$cmd"
    rs=$?
    
    if [[ -n "${WEBMIN_DEV__SSH_PRV_KEY:-}" ]] && 
       [[ -n "${WEBMIN_DEV__SSH_PUB_KEY:-}" ]]; then
        echo "Setting up development SSH keys .."
        postcmd $rs
        echo
         
        # Import SSH keys from secrets to be able to connect to the remote host
        echo "$WEBMIN_DEV__SSH_PRV_KEY" > "$key_path"
        echo "$WEBMIN_DEV__SSH_PUB_KEY" > "$key_path.pub"
        return 0
    elif [[ -n "${WEBMIN_PROD__SSH_PRV_KEY:-}" ]] &&
         [[ -n "${WEBMIN_PROD__SSH_PUB_KEY:-}" ]]; then
        echo "Setting up production SSH keys .."
        postcmd $rs
        echo
        
        # Import SSH keys from secrets to be able to connect to the remote host
        echo "$WEBMIN_PROD__SSH_PRV_KEY" > "$key_path"
        echo "$WEBMIN_PROD__SSH_PUB_KEY" > "$key_path.pub"
        return 0
    fi
}

# Upload to cloud
# Usage:
#   cloud_upload_list_delete=("$CLOUD_UPLOAD_SSH_DIR/repodata")
#   cloud_upload_list_upload=("$ROOT_REPOS/*" "$ROOT_REPOS/repodata")
#   cloud_upload cloud_upload_list_upload cloud_upload_list_delete
cloud_upload() {
    # Print new block only if defined
    local ssh_args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    if [ -n "$1" ]; then
        echo
    fi

    # Setup SSH keys on the build machine
    setup_ssh

    # Delete files on remote if needed
    if [ -n "$2" ]; then
        echo "Deleting given files in $CLOUD_UPLOAD_SSH_HOST .."
        local -n arr_del=$2
        local err=0
        for d in "${arr_del[@]}"; do
            if [ -n "$d" ]; then
                local cmd1="ssh $ssh_args $CLOUD_UPLOAD_SSH_USER@"
                cmd1+="$CLOUD_UPLOAD_SSH_HOST \"rm -rf $d\" $VERBOSITY_LEVEL"
                eval "$cmd1"
                # shellcheck disable=SC2181
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
        echo "Uploading built files to $CLOUD_UPLOAD_SSH_HOST .."
        local -n arr_upl=$1
        local err=0
        for u in "${arr_upl[@]}"; do
            if [ -n "$u" ]; then
                local cmd2="scp $ssh_args -r $u $CLOUD_UPLOAD_SSH_USER@"
                cmd2+="$CLOUD_UPLOAD_SSH_HOST:$CLOUD_UPLOAD_SSH_DIR/ $VERBOSITY_LEVEL"
                eval "$cmd2"
                # shellcheck disable=SC2181
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
    # Setup SSH keys on the build machine
    setup_ssh
    # Sign and update repos metadata in remote
    echo "Signing and updating repos metadata in $CLOUD_UPLOAD_SSH_HOST .."
    local ssh_args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    local remote_cmd="cd ~/.scripts && ./update-repo-packages-signature.bash \
        $CLOUD_UPLOAD_GPG_PASSPHRASE"
    local cmd1="ssh $ssh_args $CLOUD_UPLOAD_SSH_USER@"
    cmd1+="$CLOUD_UPLOAD_SSH_HOST \"$remote_cmd\" $VERBOSITY_LEVEL"
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
    local max="$1"
    shift
    for value in "$@"; do
        if [[ "$value" -gt "$max" ]]; then
            max="$value"
        fi
    done
    echo "$max"
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
    # shellcheck disable=SC2153
    cd "$ROOT_PROD" || exit 1
    tg=$(git rev-list --tags --max-count=1)
    ds=$(git describe --tags "$tg")
    ds="${ds/v/}"
    echo "$ds"
}

get_module_version() {
    local version=""
    
    # Check if module.info exists and extract version
    if [ -f "module.info" ]; then
        version=$(grep -E '^version=[0-9]+(\.[0-9]+)*' module.info | \
            head -n 1 | cut -d'=' -f2)
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
    date +'%Y-%m-%d %H:%M:%S %z'
}

# Get latest commit date version
get_latest_commit_date_version() {
    local theme_version
    local prod_version
    local max_prod
    local highest_version

    theme_version=$(git log -n1 --pretty='format:%cd' --date=format:'%Y%m%d%H%M')
    cd "$ROOT_PROD" || exit 1
    prod_version=$(git log -n1 --pretty='format:%cd' --date=format:'%Y%m%d%H%M')
    max_prod=("$theme_version" "$prod_version")
    highest_version=$(max "${max_prod[@]}")
    echo "$highest_version"
}

# Pull project repo and theme
make_prod_repos() {
    local root_prod="$1"
    local prod="$2"
    local cmd;
    # Webmin or Usermin
    if [ ! -d "$root_prod" ]; then
        local repo="webmin/$prod.git"
        cmd="git clone --depth 1 $GIT_BASE_URL/$repo $VERBOSITY_LEVEL"
        eval "$cmd"
        if [ ! -d "webmin" ]; then
            cmd="git clone --depth 1 $WEBMIN_REPO \
                $VERBOSITY_LEVEL"
            eval "$cmd"
        fi
    fi
    # Theme
    local theme="authentic-theme"
    if [ ! -d "$root_prod/$theme" ]; then
        cd "$root_prod" || exit 1
        local repo="webmin/$theme.git"
        cmd="git clone --depth 1 $GIT_BASE_URL/$repo $VERBOSITY_LEVEL"
        eval "$cmd"
    fi
}

# Make module repo
make_module_repo_cmd() {
    local module="$1"
    local target="$2"
    printf "git clone --depth 1 $target/%s.git %s" \
        "$module" "$VERBOSITY_LEVEL"
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
    if [ ! -d "$ROOT_DIR/build-deps" ]; then
        mkdir -p "$ROOT_DIR/build-deps"
    fi

    # Download required scripts from Webmin repo if they don't exist
    if [ ! -f "$ROOT_DIR/build-deps/makemoduledeb.pl" ] || \
       [ ! -f "$ROOT_DIR/build-deps/makemodulerpm.pl" ] || \
       [ ! -f "$ROOT_DIR/build-deps/create-module.pl" ]; then
        echo "Downloading build dependencies .."
        
        # Create temporary directory
        local temp_dir
        temp_dir=$(mktemp -d)
        cd "$temp_dir" || exit 1
        
        # Clone Webmin repository (minimal depth)
        cmd="git clone --depth 1 --filter=blob:none --sparse \
            $WEBMIN_REPO.git $VERBOSITY_LEVEL"
        eval "$cmd"
        postcmd $?
        echo
        
        cd webmin || exit 1
        
        # Copy required files to build-deps directory
        cp makemoduledeb.pl makemodulerpm.pl create-module.pl \
            "$ROOT_DIR/build-deps/"
        
        # Make scripts executable
        chmod +x "$ROOT_DIR/build-deps/"*.pl
        
        # Clean up
        cd "$ROOT_DIR" || exit 1
        remove_dir "$temp_dir"
    fi
}

# Adjust module filename depending on package type
adjust_module_filename() {
    local repo_dir="$1"
    local package_type="$2"
    local failed=0
    local temp_file

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
        if ! eval "mv \"$file\" \"$dir_name/$new_name\" \
           $VERBOSITY_LEVEL_WITH_INPUT"; then
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
    printf "%s " "$msg"
    while kill -0 $pid 2>/dev/null; do
        printf "."
        sleep 1
    done
    printf "\n"
}
