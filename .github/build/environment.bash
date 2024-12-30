#!/usr/bin/env bash
# shellcheck disable=SC2034
# environment.bash
# Copyright Ilia Ross <ilia@webmin.dev>
# Configures environment variables for the build process

# Builder email
BUILDER_PACKAGE_EMAIL="${ENV_BUILD__BUILDER_EMAIL:-ilia@webmin.dev}"
BUILDER_MODULE_EMAIL="${ENV_BUILD__BUILDER_EMAIL:-ilia@virtualmin.dev}"

# Set defaults
ROOT_DIR="${ENV_BUILD__ROOT:-$HOME}"
ROOT_REPOS="${ENV_BUILD__ROOT_REPOS:-$ROOT_DIR/repo}"
ROOT_BUILD="${ENV_BUILD__ROOT_BUILD:-$ROOT_DIR/rpmbuild}"
ROOT_RPMS="${ENV_BUILD__ROOT_RPMS:-$ROOT_BUILD/RPMS/noarch}"

# Create symlinks for Perl
PERL_SOURCE="/usr/bin/perl"
PERL_TARGET="/usr/local/bin/perl"
ln -fs "$PERL_SOURCE" "$PERL_TARGET"

# GitHub private repos access token
GITHUB_TOKEN="${ENV_BUILD__GITHUB_TOKEN}"

# Cloud upload config
CLOUD_UPLOAD_SSH_USER="${ENV_BUILD__CLOUD_UPLOAD_SSH_USER:-webmin.dev}"
CLOUD_UPLOAD_SSH_HOST="${ENV_BUILD__CLOUD_UPLOAD_SSH_HOST:-webmin.dev}"
CLOUD_UPLOAD_SSH_DIR="${ENV_BUILD__CLOUD_UPLOAD_SSH_DIR:-~/domains/download.webmin.dev/public_html}"
CLOUD_UPLOAD_GPG_PASSPHRASE="${WEBMIN_DEV__GPG_PH}"

# Define verbosity level
VERBOSITY_LEVEL=' >/dev/null 2>&1 </dev/null'
VERBOSITY_LEVEL_TO_FILE='2> /dev/null'
VERBOSITY_LEVEL_WITH_INPUT=' >/dev/null 2>&1'
if [[ "'$*'" == *"--verbose"* ]]; then
    unset VERBOSITY_LEVEL VERBOSITY_LEVEL_TO_FILE VERBOSITY_LEVEL_WITH_INPUT
fi

# Project links
GIT_BASE_URL="https://github.com"
GIT_AUTH_URL="https://${GITHUB_TOKEN}@github.com"
WEBMIN_ORG_URL="$GIT_BASE_URL/webmin"
WEBMIN_REPO="$WEBMIN_ORG_URL/webmin"
VIRTUALMIN_ORG_AUTH_URL="$GIT_AUTH_URL/virtualmin"
