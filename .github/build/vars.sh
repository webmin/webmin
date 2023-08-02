#!/usr/bin/env bash
#
# Copyright @iliajie <ilia@webmin.dev>
#
# Build variables
#
#

# Set defaults
root="${ENV_BUILD__ROOT:-$HOME}"
root_repos="${ENV_BUILD__ROOT_REPOS:-$root/repo}"
root_build="${ENV_BUILD__ROOT_BUILD:-$root/rpmbuild}"
root_rpms="${ENV_BUILD__ROOT_RPMS:-$root_build/RPMS/noarch}"

# Cloud upload config
cloud_upload_ssh_user="${ENV_BUILD__CLOUD_UPLOAD_SSH_USER:-webmin.dev}"
cloud_upload_ssh_host="${ENV_BUILD__CLOUD_UPLOAD_SSH_HOST:-webmin.dev}"
cloud_upload_ssh_dir="${ENV_BUILD__CLOUD_UPLOAD_SSH_DIR:-~/domains/builds.webmin.dev/public_html}"
cloud_upload_gpg_passphrase="${WEBMIN_DEV__GPG_PH}"

# Define verbosity level
verbosity_level=' >/dev/null 2>&1 </dev/null'
verbosity_level_to_file='2> /dev/null'
verbosity_level_with_input=' >/dev/null 2>&1'
if [[ "'$*'" == *"--debug"* ]]; then
    unset verbosity_level verbosity_level_to_file verbosity_level_with_input
fi
