# Functions for configuring the fail2ban log analyser
#
# XXX locking and logging
# XXX include in makedist.pl

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
use WebminCore;
&init_config();
our ($module_root_directory, %text, %config, %gconfig, $base_remote_user);
our %access = &get_module_acl();

sub list_filters
{
}

sub list_actions
{
}

sub list_jails
{
}

1;
