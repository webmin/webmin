#!/bin/sh
# shellcheck disable=SC1090 disable=SC2059 disable=SC2164 disable=SC2181 disable=SC2317
# webmin-setup-repo.sh
# Sets up a production or testing repository for Webmin and Usermin packages
# on Debian-based and RPM-based systems

webmin_host="download.webmin.com"
webmin_download="https://$webmin_host"
webmin_download_testing="https://download.webmin.dev"
webmin_key="developers-key.asc"
webmin_key_download="$webmin_download/$webmin_key"
webmin_key_suffix="webmin-developers"
debian_repo_file="/etc/apt/sources.list.d/webmin.list"
debian_repo_file_testing="/etc/apt/sources.list.d/webmin-testing.list"
rhel_repo_file="/etc/yum.repos.d/webmin.repo"
rhel_repo_file_testing="/etc/yum.repos.d/webmin-testing.repo"
download_curl="/usr/bin/curl"
download="$download_curl -f -s -L -O"
testing_mode=0
force_setup=0

# Colors
NORMAL="$(tput sgr0 2>/dev/null || echo '')"
GREEN="$(tput setaf 2 2>/dev/null || echo '')"
RED="$(tput setaf 1 2>/dev/null || echo '')"
BOLD="$(tput bold 2>/dev/null || echo '')"
ITALIC="$(tput sitm 2>/dev/null || echo '')"

usage() {
  echo "${RED}Error:${NORMAL} Unknown or invalid argument."
  echo "Usage: $0 [-t|--testing] [-f|--force] [-h|--help]"
  exit "$1"
}

process_args() {
  for arg in "$@"; do
    case "$arg" in
      -t|--testing) testing_mode=1 ;;
      -f|--force) force_setup=1 ;;
      -h|--help)
        echo "Usage: $0 [-t|--testing] [-f|--force] [-h|--help]"
        exit 0
        ;;
      *)
        echo "${RED}Error:${NORMAL} Unknown argument: $arg"
        echo "Usage: $0 [-t|--testing] [-f|--force] [-h|--help]"
        exit 1
        ;;
    esac
  done
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
    if command -pv dnf 1>/dev/null 2>&1; then
      install_cmd="dnf install"
      install="$install_cmd -y"
      clean="dnf clean all"
    else
      install_cmd="yum install"
      install="$install_cmd -y"
      clean="yum clean all"
    fi
  else
    echo "${RED}Error:${NORMAL} Unknown OS : $osid"
    exit 1
  fi
}

ask_confirmation() {
  if [ "$force_setup" != "1" ]; then
    if [ "$testing_mode" = "1" ]; then
      printf \
"\e[47;1;31;82mRolling builds are experimental and unstable versions used for testing\e[0m\n"
      printf \
"\e[47;1;31;82mand development purposes, may have critical bugs and breaking changes!\e[0m\n"
      printf "Setup Webmin testing repository? (y/N) "
    else
      printf "Setup Webmin repository? (y/N) "
    fi
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
      $install curl 1>/dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo "  .. failed to install 'wget'!"
        exit 1
      else
        echo "  .. done"
      fi
    fi
  fi
}

check_gpg() {
  if [ -n "$osid_debian_like" ]; then
    if [ ! -x /usr/bin/gpg ]; then
      $update 1>/dev/null 2>&1
      $install gnupg 1>/dev/null 2>&1
    fi
  fi
}

download_key() {
  rm -f "/tmp/$webmin_key"
  echo "  Downloading Webmin key .."
  download_out=$($download "$webmin_key_download" 2>&1)
  if [ $? -ne 0 ]; then
    download_out=$(echo "$download_out" | tr '\n' ' ')
    echo "  ..failed : $download_out"
    exit 1
  fi
  echo "  .. done"
}

setup_repos() {
  case "$package_type" in
    rpm)
      echo "  Installing Webmin key .."
      rpm --import "$webmin_key"
      cp -f "$webmin_key" \
        "/etc/pki/rpm-gpg/RPM-GPG-KEY-$webmin_key_suffix"
      echo "  .. done"
      if [ "$testing_mode" = "1" ]; then
        echo "  Setting up Webmin testing repository .."
        cat << EOF > "$rhel_repo_file_testing"
[webmin-testing-noarch]
name=Webmin Testing
baseurl=$webmin_download_testing
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-$webmin_key_suffix
gpgcheck=1
EOF
      else
        echo "  Setting up Webmin repository .."
        cat << EOF > "$rhel_repo_file"
[webmin-noarch]
name=Webmin Stable
baseurl=$webmin_download/download/newkey/yum
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-$webmin_key_suffix
gpgcheck=1
EOF
      fi
      echo "  .. done"
      ;;
    deb)
      rm -f \
"/usr/share/keyrings/debian-$webmin_key_suffix.gpg" \
"/usr/share/keyrings/$repoid_debian_like-$webmin_key_suffix.gpg"
      echo "  Installing Webmin key .."
      gpg --import "$webmin_key" 1>/dev/null 2>&1
      gpg --dearmor < "$webmin_key" \
        > "/usr/share/keyrings/$repoid_debian_like-$webmin_key_suffix.gpg"
      echo "  .. done"
      sources_list=$(grep -v "$webmin_host" /etc/apt/sources.list)
      echo "$sources_list" > /etc/apt/sources.list
      if [ "$testing_mode" = "1" ]; then
        echo "  Setting up Webmin testing repository .."
        echo \
"deb [signed-by=/usr/share/keyrings/$repoid_debian_like-$webmin_key_suffix.gpg] \
$webmin_download_testing webmin main" \
        > "$debian_repo_file_testing"
      else
        echo "  Setting up Webmin repository .."
        echo \
"deb [signed-by=/usr/share/keyrings/$repoid_debian_like-$webmin_key_suffix.gpg] \
$webmin_download/download/newkey/repository stable contrib" \
        > "$debian_repo_file"
      fi
      echo "  .. done"
      echo "  Cleaning repository metadata .."
      $clean 1>/dev/null 2>&1
      echo "  .. done"
      echo "  Downloading repository metadata .."
      $update 1>/dev/null 2>&1
      echo "  .. done"
      ;;
    *)
      echo "${RED}Error:${NORMAL} Cannot set up repositories on this system."
      exit 1
      ;;
  esac
}

final_msg() {
  if [ ! -x "/usr/bin/webmin" ]; then
    echo "Webmin and Usermin can be installed with:"
    echo "  ${GREEN}${BOLD}${ITALIC}$install_cmd webmin usermin${NORMAL}"
  fi
  exit 0
}

# Main
process_args "$@"
check_permission
prepare_tmp
detect_os
ask_confirmation
check_downloader
check_gpg
download_key
setup_repos
final_msg
