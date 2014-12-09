# Common functions for theme CGIs

use strict;
use warnings;
BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

sub right_frame_cgi
{
my %tconfig = &foreign_config("gray-theme");
if ($tconfig{'newright'} eq '1') {
	return 'newright.cgi';
	}
elsif ($tconfig{'newright'} eq '0') {
	return 'right.cgi';
	}
else {
	# XXX add more logic here
	return 'right.cgi';
	}
}

1;
