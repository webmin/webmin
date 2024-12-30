#!/usr/bin/env bash
# shellcheck disable=SC1091
# bootstrap.bash
# Copyright Ilia Ross <ilia@webmin.dev>
# Bootstrap the build process

# Source general build functions
source "./functions.bash" || exit 1

# Source build variables
source ./environment.bash || exit 1
