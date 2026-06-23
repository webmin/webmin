#!/usr/local/bin/perl
# Decides whether the standalone systemd module should be shown.

use strict;
use warnings;
use lib "..";

use WebminCore;

# is_installed(mode)
# Returns Webmin's install-check code for systems with systemctl available.
sub is_installed
{
# Mode 0 is a boolean probe; mode 1 asks whether the module should be visible.
return 0 if (!has_command("systemctl"));
return $_[0] ? 2 : 1;
}

1;
