require 'postfix-lib.pl';    ## no critic
use strict;
use warnings;
our ($version_file);

sub module_install
{
&unlink_logged($version_file);
}
