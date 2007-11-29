
require 'htaccess-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the htaccess module
sub acl_security_form
{
# Write files as user
print &ui_table_row($text{'acl_user'},
	&ui_radio("user_def", $_[0]->{'user'} eq "*" ? 1 : 0,
		  [ [ 1, $text{'acl_same'} ],
		    [ 0, &unix_user_input("user",
			$_[0]->{'user'} eq "*" ? "" : $_[0]->{'user'}) ] ]), 3);

# Allowed directories
print &ui_table_row($text{'acl_dirs'},
	&ui_textarea("dirs", join("\n", split(/\t+/, $_[0]->{'dirs'})),
		     5, 60)."<br>".
	&ui_checkbox("home", 1, $text{'acl_home'}, $_[0]->{'home'}), 3);

# Allow sync setup
print &ui_table_row($text{'acl_sync'},
	&ui_yesno_radio("sync", $_[0]->{'sync'}));

# Limit to user/group editing
print &ui_table_row($text{'acl_uonly'},
	&ui_radio("uonly", $_[0]->{'uonly'},
		  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));
}

# acl_security_save(&options)
# Parse the form for security options for the cron module
sub acl_security_save
{
$_[0]->{'user'} = $in{'user_def'} ? "*" : $in{'user'};
$in{'dirs'} =~ s/\r//g;
$_[0]->{'dirs'} = join("\t", split(/\n/, $in{'dirs'}));
$_[0]->{'home'} = $in{'home'};
$_[0]->{'sync'} = $in{'sync'};
$_[0]->{'uonly'} = $in{'uonly'};
}

