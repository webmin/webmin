
require 'cron-lib.pl';
do '../ui-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the cron module
sub acl_security_form
{
local $m = $_[0]->{'mode'};
print &ui_table_row($text{'acl_users'},
	&ui_radio("mode", $m,
	 [ [ 0, "$text{'acl_all'}<br>" ],
	   [ 3, "$text{'acl_this'}<br>" ],
	   [ 1, $text{'acl_only'}." ".
		&ui_textbox("userscan",
			$m == 1 ? $_[0]->{'users'} : "", 40)." ".
		&user_chooser_button("userscan", 1)."<br>" ],
	   [ 2, $text{'acl_except'}." ".
		&ui_textbox("userscannot",
			$m == 2 ? $_[0]->{'users'} : "", 40)." ".
		&user_chooser_button("userscannot", 1)."<br>" ],
	   [ 5, $text{'acl_gid'}." ".
		&ui_textbox("gid",
		    $m == 5 ? scalar(getgrgid($_[0]->{'users'})) : "", 13)." ".
		&group_chooser_button("gid", 0)."<br>" ],
	   [ 4, $text{'acl_uid'}." ".
		&ui_textbox("uidmin", $_[0]->{'uidmin'}, 6)." - ".
		&ui_textbox("uidmax", $_[0]->{'uidmax'}, 6)."<br>" ],
	 ]), 3);

print &ui_table_row($text{'acl_control'},
	&ui_radio("allow", $_[0]->{'allow'},
		[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_command'},
	&ui_radio("command", $_[0]->{'command'},
		[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_create'},
	&ui_radio("create", $_[0]->{'create'},
		[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_delete'},
	&ui_radio("delete", $_[0]->{'delete'},
		[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_move'},
	&ui_radio("move", $_[0]->{'move'},
		[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_kill'},
	&ui_radio("kill", $_[0]->{'kill'},
		[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_hourly'},
	&ui_radio("hourly", $_[0]->{'hourly'},
		[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ],
		  [ 2, $text{'acl_hourlydef'} ] ]), 3);
}

# acl_security_save(&options)
# Parse the form for security options for the cron module
sub acl_security_save
{
$_[0]->{'mode'} = $in{'mode'};
$_[0]->{'users'} = $in{'mode'} == 0 || $in{'mode'} == 3 ||
		   $in{'mode'} == 4 ? "" :
		   $in{'mode'} == 5 ? scalar(getgrnam($in{'gid'})) :
		   $in{'mode'} == 1 ? $in{'userscan'}
				    : $in{'userscannot'};
$_[0]->{'uidmin'} = $in{'mode'} == 4 ? $in{'uidmin'} : "";
$_[0]->{'uidmax'} = $in{'mode'} == 4 ? $in{'uidmax'} : "";
$_[0]->{'allow'} = $in{'allow'};
$_[0]->{'command'} = $in{'command'};
$_[0]->{'create'} = $in{'create'};
$_[0]->{'delete'} = $in{'delete'};
$_[0]->{'move'} = $in{'move'};
$_[0]->{'kill'} = $in{'kill'};
$_[0]->{'hourly'} = $in{'hourly'};
}

