
use strict;
use warnings;
require 'time-lib.pl';
our (%text);

sub acl_security_form
{
my ($o) = @_;
print &ui_table_row(text{'acl_sys'},
	&ui_yesno_radio("sysdate", $o->{'sysdate'}, 0, 1));
print &ui_table_row(text{'acl_hw'},
	&ui_yesno_radio("hwdate", $o->{'hwdate'}, 0, 1));
print &ui_table_row(text{'acl_timezone'},
	&ui_yesno_radio("timezone", $o->{'timezone'}));
print &ui_table_row(text{'acl_ntp'},
	&ui_yesno_radio("ntp", $o->{'ntp'}));
}

sub acl_security_save
{
my ($o, $in) = @_;
$o->{'sysdate'} = $in->{'sysdate'};
$o->{'hwdate'} = $in->{'hwdate'};
$o->{'timezone'} = $in->{'timezone'};
$o->{'ntp'} = $in->{'ntp'};
}
