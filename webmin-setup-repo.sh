#!/bin/sh
# shellcheck disable=SC1090 disable=SC2059 disable=SC2164 disable=SC2181 disable=SC2317
# webmin-setup-repo.sh
# Sets up a stable, prerelease, or unstable repository to provide Webmin and
# Usermin packages on Debian-based and RPM-based systems

# Default values that can be overridden
repo_host="download.webmin.com"
repo_download="https://$repo_host"
repo_download_prerelease="https://rc.download.webmin.dev"
repo_download_unstable="https://download.webmin.dev"
repo_key="developers-key.asc"
repo_key_download="$repo_download/$repo_key"
repo_key_suffix="webmin-developers"
repo_name="webmin-stable"
repo_name_prerelease="webmin-prerelease"
repo_name_unstable="webmin-unstable"
repo_component="main"
repo_dist="stable"
repo_section="contrib"
repo_description="Webmin Releases"
repo_description_prerelease="Webmin Prerelease"
repo_description_unstable="Webmin Unstable"
install_check_binary="/usr/bin/webmin"
install_message="Webmin and Usermin can be installed with:"
install_packages="webmin usermin"
repo_auth_user=""
repo_auth_pass=""

# Repository mode (stable, prerelease, unstable)
repo_mode="stable"

download_curl="/usr/bin/curl"
download="$download_curl -f -s -L -O"
force_setup=0

# Colors
NORMAL="$(tput sgr0 2>/dev/null || echo '')"
GREEN="$(tput setaf 2 2>/dev/null || echo '')"
RED="$(tput setaf 1 2>/dev/null || echo '')"
BOLD="$(tput bold 2>/dev/null || echo '')"
ITALIC="$(tput sitm 2>/dev/null || echo '')"

usage() {
  if [ -n "${1-}" ]; then
    echo "${RED}Error:${NORMAL} Unknown or invalid argument: $1"
  fi
  echo
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

General options:
  -f, --force                Force setup without confirmation
  -h, --help                 Display this help message

Repository types:
  --stable                   Set up the stable repo, built with extra testing
  --prerelease               Set up the prerelease repo built from latest tag
  --unstable                 Set up unstable repo built from the latest commit

Repository configuration:
  --host=<host>              Main repository host
  --prerelease-host=<host>   Prerelease repository host
  --unstable-host=<host>     Unstable repository host
  --key=<key>                Repository signing key file
  --key-suffix=<suffix>      Repository key suffix for file naming
  --auth-user=<user>         Repository authentication username
  --auth-pass=<pass>         Repository authentication password
  --pkg-prefs=<dist:pkg|pr*> Package preferences for repository
  --repo-prefs=<dist:opts>   Optional preferences for repository

Repository metadata:
  --name=<name>              Base name for repository (default: webmin)
  --description=<desc>       Description for repository (default: Webmin)
  --component=<comp>         Repository component (default: main)
  --section=<sec>            Repository section (default: contrib)
  --dist=<dist>              Distribution name (default: stable)

Post-installation options:
  --check-binary=<path>      Binary to check in post-install
  --install-message=<msg>    Message to show in post-install if binary not found
  --install-packages=<pkgs>  Packages to suggest for installation

EOF
  exit 1
}

post_status() {
    status="$1"
    message="$2"
    if [ "$status" -eq 0 ]; then
        echo "  .. done"
    else
        if [ -n "$message" ]; then
          echo "  .. failed : $message"
        else
          echo "  .. failed"
        fi
        exit "$status"
    fi
}

process_args() {
  for arg in "$@"; do
    case "$arg" in
      --stable) repo_mode="stable" ;;
      --prerelease|--rc) repo_mode="prerelease" ;;
      --unstable|--testing|-t) repo_mode="unstable" ;;
      -f|--force) force_setup=1 ;;
      -h|--help) usage ;;
      --host=*)
        repo_host="${arg#*=}"
        repo_download="https://$repo_host"
        repo_key_download="$repo_download/$repo_key"
        ;;
      --prerelease-host=*)
        repo_download_prerelease="https://${arg#*=}"
        ;;
      --unstable-host=*)
        repo_download_unstable="https://${arg#*=}"
        ;;
      --key=*)
        repo_key="${arg#*=}"
        repo_key_download="$repo_download/$repo_key"
        ;;
      --key-suffix=*)
        repo_key_suffix="${arg#*=}"
        ;;
      --auth-user=*)
        repo_auth_user="${arg#*=}"
        ;;
      --auth-pass=*)
        repo_auth_pass="${arg#*=}"
        ;;
      --pkg-prefs=*)
        repo_pkg_prefs="${arg#*=}"
        ;;
      --repo-prefs=*)
          repo_prefs="${arg#*=}"
        ;;
      --name=*)
        base_name="${arg#*=}"
        repo_name="$base_name"
        repo_name_prerelease="${base_name}-prerelease"
        repo_name_unstable="${base_name}-unstable"
        ;;
      --description=*)
        base_description="${arg#*=}"
        repo_description="$base_description Releases"
        repo_description_prerelease="${base_description} Prerelease"
        repo_description_unstable="${base_description} Unstable"
        ;;
      --component=*)
        repo_component="${arg#*=}"
        ;;
      --section=*)
        repo_section="${arg#*=}"
        ;;
      --dist=*)
        repo_dist="${arg#*=}"
        ;;
      --check-binary=*)
        install_check_binary="${arg#*=}"
        ;;
      --install-message=*)
        install_message="${arg#*=}"
        ;;
      --install-packages=*)
        install_packages="${arg#*=}"
        ;;
      *)
        usage "$arg"
        ;;
    esac
  done

  # Set active repo variables based on mode
  case "$repo_mode" in
    prerelease)
      active_repo_name="$repo_name_prerelease"
      active_repo_description="$repo_description_prerelease"
      active_repo_download="$repo_download_prerelease"
      if [ "$repo_dist" = "stable" ]; then
        repo_dist="webmin"
      fi
      ;;
    unstable)
      active_repo_name="$repo_name_unstable"
      active_repo_description="$repo_description_unstable"
      active_repo_download="$repo_download_unstable"
      if [ "$repo_dist" = "stable" ]; then
        repo_dist="webmin"
      fi
      ;;
    *)
      active_repo_name="$repo_name"
      active_repo_description="$repo_description"
      active_repo_download="$repo_download"
      ;;
  esac
}

check_permission() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "${RED}Error:${NORMAL} \`$(basename "$0")\` must be run as root!" >&2
    exit 1
  fi
}

prepare_tmp() {
  cd "/tmp" 1>/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "${RED}Error:${NORMAL} Failed to switch to \`/tmp\`!"
    exit 1
  fi
}

detect_os() {
  osrelease="/etc/os-release"
  if [ ! -f "$osrelease" ]; then
    echo "${RED}Error:${NORMAL} Cannot detect OS!"
    exit 1
  fi
  . "$osrelease"
  if [ -n "${ID_LIKE}" ]; then
    osid="$ID_LIKE"
  else
    osid="$ID"
  fi
  if [ -z "$osid" ]; then
    echo "${RED}Error:${NORMAL} Failed to detect OS!"
    exit 1
  fi

  osid_debian_like=$(echo "$osid" | grep "debian\|ubuntu")
  osid_rhel_like=$(echo "$osid" | grep "rhel\|fedora\|centos\|openEuler")
  osid_suse_like=$(echo "$osid" | grep "suse")
  repoid_debian_like=debian
  if [ -n "${ID}" ]; then
    repoid_debian_like="${ID}"
  fi

  if [ -n "$osid_debian_like" ]; then
    package_type=deb
    install_cmd="apt-get install --install-recommends"
    install="$install_cmd --quiet --assume-yes"
    clean="apt-get clean"
    update="apt-get update"
  elif [ -n "$osid_rhel_like" ]; then
    package_type=rpm
    repo_extra_opts=""
    if command -pv dnf 1>/dev/null 2>&1; then
      install_cmd="dnf install"
      install="$install_cmd -y"
      clean="dnf clean all"
      update="dnf makecache"
    else
      install_cmd="yum install"
      install="$install_cmd -y"
      clean="yum clean all"
      update="yum makecache"
    fi
  elif [ -n "$osid_suse_like" ]; then
    package_type=rpm
    install_cmd="zypper install"
    install="$install_cmd -y"
    clean="zypper clean"
    update="zypper refresh"
    repo_extra_opts="autorefresh=1"
  else
    echo "${RED}Error:${NORMAL} Unknown OS : $osid"
    exit 1
  fi
}

set_os_variables() {
  # Debian-based
  debian_repo_file="/etc/apt/sources.list.d/$active_repo_name.list"
  
  # RPM-based
  rpm_repo_dir="/etc/yum.repos.d"
  if [ -n "$osid_suse_like" ]; then
    rpm_repo_dir="/etc/zypp/repos.d"
  fi
  rpm_repo_file="$rpm_repo_dir/$active_repo_name.repo"
}

ask_confirmation() {
    repo_desc_formatted=$(echo "$active_repo_description" | \
      sed 's/\([^ ]*\)\(.*\)/\1\L\2/')
  case "$repo_mode" in
    prerelease)
      printf \
"\e[47;1;31;82mPrerelease builds are automated from the latest tagged release\e[0m\n"
      ;;
    unstable)
      printf \
"\e[47;1;31;82mUnstable builds are automated experimental versions designed for\e[0m\n"
    printf \
"\e[47;1;31;82mdevelopment, often containing critical bugs and breaking changes\e[0m\n"
      ;;
  esac
  if [ "$force_setup" != "1" ]; then
    printf "Setup ${repo_desc_formatted} repository? (y/N) "
    read -r sslyn
    if [ "$sslyn" != "y" ] && [ "$sslyn" != "Y" ]; then
      exit 0
    fi
  fi
}

check_downloader() {
  if [ ! -x "$download_curl" ]; then
    if [ -x "/usr/bin/wget" ]; then
      download="/usr/bin/wget -nv"
    elif [ -x "/usr/bin/fetch" ]; then
      download="/usr/bin/fetch"
    else
      echo "  Installing required ${ITALIC}curl${NORMAL} from OS repos .."
      install_output=$($install curl 2>&1)
      post_status $? "$(echo "$install_output" | tr '\n' ' ')"
    fi
  fi
}

check_gpg() {
  if [ -n "$osid_debian_like" ]; then
    if [ ! -x /usr/bin/gpg ]; then
      echo "  Installing required ${ITALIC}gnupg${NORMAL} from OS repos .."
      $update 1>/dev/null 2>&1
      install_output=$($install gnupg 2>&1)
      post_status $? "$(echo "$install_output" | tr '\n' ' ')"
    fi
  fi
}

enforce_package_priority() {
  repo_pkg_pref=$1
  disttarget=$2

  # Save and set IFS to newline only
  old_ifs=$IFS
  IFS='
'
  
  # Extract all entries for the target distribution
  for entry in $repo_pkg_pref; do
    case "$entry" in
      ${disttarget}:*)
        # Extract the action and the rest of the entry
        action=${entry#"$disttarget:"}
        action=${action%%:*}
        entry=${entry#"$disttarget:$action:"}
        entry=$disttarget:$entry

        # Remove the prefix
        spec="${entry#"${disttarget}":}"
        
        # Parse package=priority=version format
        package="${spec%%=*}"
        remainder="${spec#*=}"
        
        # Check if remainder is empty or just a package name
        if [ "$remainder" = "$spec" ]; then
          printf "%s\t%s %s %s\n" "${action:-}" "$package" "" ""
        else
          priority="${remainder%%=*}"
          version="${remainder#*=}"
          [ "$version" = "$remainder" ] && version=""
          printf "%s\t%s %s %s\n" "${action:-}" "$package" "${priority:-}" "${version:-}"
        fi
        ;;
    esac
  done

  # Restore IFS
  IFS=$old_ifs
}

download_key() {
  rm -f "/tmp/$repo_key"
  echo "  Downloading Webmin developers key .."
  download_out=$($download "$repo_key_download" 2>&1)
  post_status $? "$(echo "$download_out" | tr '\n' ' ')"
}

rpm_repo_prefs() {
  for pref in $repo_prefs; do
    if echo "$pref" | grep "^rpm:" >/dev/null 2>&1; then
      val=$(echo "$pref" | sed 's/^rpm://')
      printf '%s\n' "$val"
    fi
  done
}

setup_repos() {
  repo_desc_formatted=$(echo "$active_repo_description" | \
      sed 's/\([^ ]*\)\(.*\)/\1\L\2/')
  
  # Construct auth URL if credentials provided
  repo_auth_url="$active_repo_download"
  if [ -n "$repo_auth_user" ] && [ -n "$repo_auth_pass" ]; then
      protocol="${repo_auth_url%%://*}"
      rest="${repo_auth_url#*://}"
      repo_auth_url="${protocol}://$repo_auth_user:$repo_auth_pass@$rest"
  fi
  
  case "$package_type" in
    rpm)
      echo "  Installing Webmin developers key .."
      rpm --import "$repo_key"
      mkdir -p "/etc/pki/rpm-gpg"
      cp -f "$repo_key" \
        "/etc/pki/rpm-gpg/RPM-GPG-KEY-$repo_key_suffix"
      echo "  .. done"
      # Configure packages extra preferences if given
      if [ -n "$repo_pkg_prefs" ]; then
        repo_pkg_prefs_rs=$(enforce_package_priority "$repo_pkg_prefs" "rpm")
        repo_extra_opts=$(printf '%s\n' "$repo_pkg_prefs_rs" | awk -F'\t' '
          function trim(s) {
            sub(/^[ \t]+/, "", s)
            sub(/[ \t]+$/, "", s)
            return s
          }
          {
            key = trim($1)
            val = trim($2)
            if (key in opts)
              opts[key] = opts[key] " " val
            else
              opts[key] = val
          }
          END {
            for (k in opts)
              printf "%s=%s\n", k, trim(opts[k])
          }')
        if [ -n "$repo_pkg_prefs_rs" ]; then
          echo "  Setting up package exclusion for repository .."
          echo "  .. done"
        fi
      fi
      # Configure the repository
      echo "  Setting up ${repo_desc_formatted} repository .."
      if [ "$repo_mode" = "stable" ]; then
        repo_url="$active_repo_download/download/newkey/yum"
      else
        repo_url="$repo_auth_url"
      fi
      repo_extra_opts_caller=$(rpm_repo_prefs)
      cat << EOF > "$rpm_repo_file"
[$active_repo_name-noarch]
name=$active_repo_description
baseurl=$repo_url
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-$repo_key_suffix
gpgcheck=1
EOF
      # Append non-empty options if they exist to keep config file clean
      [ -n "$repo_extra_opts" ] && \
        printf '%s\n' "$repo_extra_opts" >> "$rpm_repo_file"
      [ -n "$repo_extra_opts_caller" ] && \
        printf '%s\n' "$repo_extra_opts_caller" >> "$rpm_repo_file"
      echo "  .. done"
      echo "  Downloading repository metadata .."
      update_output=$($update 2>&1)
      post_status $? "$update_output"
      ;;
    deb)
      rm -f \
"/usr/share/keyrings/debian-$repo_key_suffix.gpg" \
"/usr/share/keyrings/$repoid_debian_like-$repo_key_suffix.gpg"
      echo "  Installing Webmin developers key .."
      gpg --import "$repo_key" 1>/dev/null 2>&1
      gpg --dearmor < "$repo_key" \
        > "/usr/share/keyrings/$repoid_debian_like-$repo_key_suffix.gpg"
      post_status $?
      sources_list=$(grep -v "$repo_host" /etc/apt/sources.list)
      echo "$sources_list" > /etc/apt/sources.list
      # Configure packages priority if provided
      debian_repo_prefs="/etc/apt/preferences.d/$repoid_debian_like-$repo_dist-package-priority"
      if [ -n "$repo_pkg_prefs" ]; then
        # Clear the file first
        : > "$debian_repo_prefs"
        
        # Process all matching packages
        pkg_lines=$(enforce_package_priority "$repo_pkg_prefs" "deb")
        tab=$(printf '\t')
        while IFS="$tab" read -r action rest || [ -n "$action" ]; do
          [ -n "$action" ] || continue
          # shellcheck disable=SC2086
          IFS=' ' set -- $rest
          package=$1
          priority=$2
          version=$3
          [ -n "$package" ] || continue
          # Process the action
          case $action in
            # Set package priority
            pin)
              if [ -n "$version" ]; then
                  pin_line="Pin: version /$version\$/"
              else
                  pin_line="Pin: release *"
              fi
              cat >> "$debian_repo_prefs" <<EOF
Package: $package
$pin_line
Pin-Priority: ${priority:-500}

EOF
            ;;
          esac
      done <<EOF
$pkg_lines
EOF
      elif [ -f "$debian_repo_prefs" ]; then
        echo "  Cleaning up package priority configuration .."
        rm -f "$debian_repo_prefs"
        echo "  .. done"
      fi
      # Configure the repository
      echo "  Setting up ${repo_desc_formatted} repository .."
      if [ "$repo_mode" = "stable" ]; then
        repo_line="deb [signed-by=/usr/share/keyrings/$repoid_debian_like-$repo_key_suffix.gpg] \
$active_repo_download/download/newkey/repository $repo_dist $repo_section"
      else
        repo_line="deb [signed-by=/usr/share/keyrings/$repoid_debian_like-$repo_key_suffix.gpg] \
$active_repo_download $repo_dist $repo_component"
      fi
      echo "$repo_line" > "$debian_repo_file"
      
      # Handle APT authentication if credentials provided
      if [ -n "$repo_auth_user" ] && [ -n "$repo_auth_pass" ]; then
        mkdir -p "/etc/apt/auth.conf.d"
        auth_file="/etc/apt/auth.conf.d/$active_repo_name.conf"
        auth_domain="${active_repo_download#*://}"
        auth_domain="${auth_domain%%/*}"
        
        # Remove existing entry for this domain if exists
        if [ -f "$auth_file" ]; then
          sed -i "/machine $auth_domain/d" "$auth_file"
        fi
        
        # Add new authentication entry
        echo "machine $auth_domain login $repo_auth_user password $repo_auth_pass" >> "$auth_file"
        chmod 600 "$auth_file"
      fi
      echo "  .. done"

      echo "  Cleaning repository metadata .."
      $clean 1>/dev/null 2>&1
      echo "  .. done"
      echo "  Downloading repository metadata .."
      update_output=$($update 2>&1)
      post_status $? "$update_output"
      ;;
    *)
      echo "${RED}Error:${NORMAL} Cannot set up repositories on this system."
      exit 1
      ;;
  esac
}

final_msg() {
  if [ "$install_check_binary" != "0" ] && [ ! -x "$install_check_binary" ]; then
    echo "$install_message"
    echo "  ${GREEN}${BOLD}${ITALIC}$install_cmd $install_packages${NORMAL}"
  fi
  
  exit 0
}

# Main
process_args "$@"
check_permission
prepare_tmp
detect_os
set_os_variables
ask_confirmation
check_downloader
check_gpg
download_key
setup_repos
final_msg
