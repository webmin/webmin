
require 'fetchmail-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the fetchmail module
sub acl_security_form
{
my ($o) = @_;

print &ui_table_row($text{'acl_users'},
    &ui_radio_table("mode", $o->{'mode'},
	[ [ 0, $text{'acl_all'} ],
	  [ 3, $text{'acl_this'} ],
	  [ 1, $text{'acl_only'},
	    &ui_users_textbox("userscan",
		$o->{'mode'} == 1 ? $o->{'users'} : "") ],
	  [ 2, $text{'acl_except'},
	    &ui_users_textbox("userscannot",
		$o->{'mode'} == 2 ? $o->{'users'} : "") ],
	]));

print &ui_table_row($text{'acl_cron'},
	&ui_yesno_radio("cron", $o->{'cron'}));

print &ui_table_row($text{'acl_daemon'},
	&ui_yesno_radio("daemon", $o->{'daemon'}));
}

# acl_security_save(&options)
# Parse the form for security options for the fetchmail module
sub acl_security_save
{
my ($o) = @_;

$o->{'mode'} = $in{'mode'};
$o->{'users'} = $in{'mode'} == 0 || $in{'mode'} == 3 ? "" :
		$in{'mode'} == 1 ? $in{'userscan'} :
				   $in{'userscannot'};
$o->{'cron'} = $in{'cron'};
$o->{'daemon'} = $in{'daemon'};
}

