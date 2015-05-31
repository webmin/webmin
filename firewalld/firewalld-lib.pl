# Functions for managing firewalld
#
# XXX longdesc
# XXX makedist.pl
# XXX integration with other modules?

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
use WebminCore;
&init_config();
do 'md5-lib.pl';
our ($module_root_directory, %text, %config, %gconfig);
our %access = &get_module_acl();

1;

