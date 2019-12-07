
do 'webminlog-lib.pl';
&foreign_require("acl", "acl-lib.pl");

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
# Allowed modules
print &ui_table_row($text{'acl_mods'},
	&ui_radio("mods_def", $_[0]->{'mods'} eq "*" ? 1 : 0,
		  [ [ 1, $text{'acl_all'} ],
                    [ 0, $text{'acl_sel'} ] ])."<br>\n".
	&ui_select("mods",
		   [ split(/\s+/, $_[0]->{'mods'}) ],
		   [ map { [ $_->{'dir'}, $_->{'desc'} ] }
			 &get_all_module_infos() ],
		   10, 1),
	3);

# Allowed users
print &ui_table_row($text{'acl_users'},
	&ui_radio("users_def", $_[0]->{'users'} eq "*" ? 1 : 0,
		  [ [ 1, $text{'acl_all'} ],
		    [ 0, $text{'acl_sel'} ] ])."<br>\n".
	&ui_select("users",
		   [ split(/\s+/, $_[0]->{'users'}) ],
		   [ map { $_->{'name'} } &acl::list_users() ],
		   10, 1),
	3);

# Rollback
print &ui_table_row($text{'acl_rollback'},
	&ui_yesno_radio("rollback", $_[0]->{'rollback'}));
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
$_[0]->{'mods'} = $in{'mods_def'} ? "*" : join(" ", split(/\0/, $in{'mods'}));
$_[0]->{'users'} = $in{'users_def'} ? "*" : join(" ", split(/\0/,$in{'users'}));
$_[0]->{'rollback'} = $in{'rollback'};
}

