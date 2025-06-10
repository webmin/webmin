use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in);

require 'at-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the at module
sub acl_security_form
{
my ($o) = @_;

print &ui_table_row($text{'acl_users'},
    &ui_radio_table("mode", $o->{'mode'},
	[ [ 0, $text{'acl_all'} ],
	  [ 3,$text{'acl_this'} ],
	  [ 1, $text{'acl_only'},
		&ui_textbox("userscan", $o->{'mode'} == 1 ? $o->{'users'} : "", 40)." ".&user_chooser_button("userscan", 1) ],
	  [ 2, $text{'acl_except'},
		&ui_textbox("userscannot", $o->{'mode'} == 2 ? $o->{'users'} : "", 40)." ".&user_chooser_button("userscannot", 1) ],
	]), 3);

print &ui_table_row($text{'acl_allow'},
	&ui_yesno_radio("allow", $o->{'allow'}), 3);

print &ui_table_row($text{'acl_stop'},
	&ui_yesno_radio("stop", $o->{'stop'}), 3);
}

# acl_security_save(&options)
# Parse the form for security options for the cron module
sub acl_security_save
{
my ($o) = @_;
$o->{'mode'} = $in{'mode'};
$o->{'users'} = $in{'mode'} == 0 || $in{'mode'} == 3 ? "" :
		$in{'mode'} == 1 ? $in{'userscan'}
				 : $in{'userscannot'};
$o->{'allow'} = $in{'allow'};
$o->{'stop'} = $in{'stop'};
}

