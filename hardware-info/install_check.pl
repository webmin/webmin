#!/usr/local/bin/perl
# Decide whether the Linux sysfs hardware inventory is available.

use strict;
use warnings;
use lib "..";

use WebminCore;

# is_installed(mode)
# Returns Webmin's install-check code when the sysfs device tree is present.
sub is_installed
{
return 0 if (!-d "/sys" || !-d "/sys/devices");
return $_[0] ? 2 : 1;
}

1;

