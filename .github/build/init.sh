#!/usr/bin/env bash
#
# Copyright @iliajie <ilia@webmin.dev>
#
# Build init
#
#

# Set up SSH dev keys
if [ -n "$WEBMIN_DEV__SSH_PRV_KEY" ] && [ -n "$WEBMIN_DEV__SSH_PUB_KEY" ]; then
    # Generate new pair with right permissions
    cmd="ssh-keygen -t rsa -q -f \"$HOME/.ssh/id_rsa\" -N \"\"$verbosity_level"
    eval "$cmd"
    # Import SSH keys from secrets to be able to connect to the remote host
    echo "$WEBMIN_DEV__SSH_PRV_KEY" > "$HOME/.ssh/id_rsa"
    echo "$WEBMIN_DEV__SSH_PUB_KEY" > "$HOME/.ssh/id_rsa.pub"

# Set up SSH production keys
elif [ -n "$WEBMIN_PROD__SSH_PRV_KEY" ] && [ -n "$WEBMIN_PROD__SSH_PUB_KEY" ]; then
    # Generate new pair with right permissions
    cmd="ssh-keygen -t rsa -q -f \"$HOME/.ssh/id_rsa\" -N \"\"$verbosity_level"
    eval "$cmd"
    # Import SSH keys from secrets to be able to connect to the remote host
    echo "$WEBMIN_PROD__SSH_PRV_KEY" > "$HOME/.ssh/id_rsa"
    echo "$WEBMIN_PROD__SSH_PUB_KEY" > "$HOME/.ssh/id_rsa.pub"
fi

# Create symlink to Perl
ln -fs /usr/bin/perl /usr/local/bin/perl
