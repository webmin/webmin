
do 'webminlog-lib.pl';
&foreign_require("acl", "acl-lib.pl");

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
my ($o) = @_;

# Allowed modules
print &ui_table_row($text{'acl_mods'},
	&ui_radio("mods_def", $o->{'mods'} eq "*" ? 1 : 0,
		  [ [ 1, $text{'acl_all'} ],
                    [ 0, $text{'acl_sel'} ] ])."<br>\n".
	&ui_select("mods",
		   [ split(/\s+/, $o->{'mods'}) ],
		   [ map { [ $_->{'dir'}, $_->{'desc'} ] }
			 &get_all_module_infos() ],
		   10, 1),
	3);

# Allowed users
print &ui_table_row($text{'acl_users'},
	&ui_radio("users_def", $o->{'users'} eq "*" ? 1 :
			       $o->{'users'} eq "x" ? 2 : 0,
		  [ [ 1, $text{'acl_all'} ],
		    [ 2, $text{'acl_self'} ],
		    [ 0, $text{'acl_sel'} ] ])."<br>\n".
	&ui_select("users",
		   [ split(/\s+/, $o->{'users'}) ],
		   [ map { $_->{'name'} } &acl::list_users() ],
		   10, 1),
	3);

# Rollback
print &ui_table_row($text{'acl_rollback'},
	&ui_yesno_radio("rollback", $o->{'rollback'}));

# Setup notifications
print &ui_table_row($text{'acl_notify'},
	&ui_yesno_radio("notify", $o->{'notify'}));
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
my ($o) = @_;
$o->{'mods'} = $in{'mods_def'} ? "*" : join(" ", split(/\0/, $in{'mods'}));
$o->{'users'} = $in{'users_def'} == 1 ? "*" :
		$in{'users_def'} == 2 ? "x" :
			join(" ", split(/\0/,$in{'users'}));
$o->{'rollback'} = $in{'rollback'};
$o->{'notify'} = $in{'notify'};
}

