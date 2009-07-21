
do 'rbac-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the RBAC module
sub acl_security_form
{
$ui_table_cols = 4;
$ui_table_pos = 0;

print &ui_table_row($text{'acl_users'},
		    &ui_radio("users", $_[0]->{'users'},
			      [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_roles'},
		    &ui_radio("roles", $_[0]->{'roles'},
			      [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

local $ra = $_[0]->{'roleassign'} eq "*" ? 0 :
	    $_[0]->{'roleassign'} eq "x" ? 1 : 2;
print &ui_table_row($text{'acl_roleassign'},
		    &ui_radio("roleassign_def", $ra,
			      [ [ 0, $text{'acl_roleassign0'} ],
				[ 1, $text{'acl_roleassign1'} ],
				[ 2, $text{'acl_roleassign2'} ] ])."\n".
		    &ui_textbox("roleassign",
			$ra == 2 ? join(" ", split(/,/, $_[0]->{'roleassign'})) : "", 40),
		    3);

local $ra = $_[0]->{'profassign'} eq "*" ? 0 :
	    $_[0]->{'profassign'} eq "x" ? 1 : 2;
print &ui_table_row($text{'acl_profassign'},
		    &ui_radio("profassign_def", $ra,
			      [ [ 0, $text{'acl_profassign0'} ],
				[ 1, $text{'acl_profassign1'} ],
				[ 2, $text{'acl_profassign2'} ] ])."<br>\n".
		    &profiles_input("profassign", $ra == 2 ? $_[0]->{'profassign'} : ""),
		    3);

print &ui_table_row($text{'acl_auths'},
		    &ui_radio("auths", $_[0]->{'auths'},
			      [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_authassign'},
		    &ui_radio("authassign", $_[0]->{'authassign'},
			      [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_profs'},
		    &ui_radio("profs", $_[0]->{'profs'},
			      [ [ 1, $text{'yes'} ], [ 2, $text{'acl_ro'} ],
				[ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_execs'},
		    &ui_radio("execs", $_[0]->{'execs'},
			      [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_projects'},
		    &ui_radio("projects", $_[0]->{'projects'},
			      [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
$_[0]->{'roles'} = $in{'roles'};
$_[0]->{'users'} = $in{'users'};
$_[0]->{'roleassign'} = $in{'roleassign_def'} == 0 ? "*" :
			$in{'roleassign_def'} == 1 ? "x" :
				join(",", split(/\s+/, $in{'roleassign'}));
$_[0]->{'profassign'} = $in{'profassign_def'} == 0 ? "*" :
			$in{'profassign_def'} == 1 ? "x" :
				join(",", split(/\0/, $in{'profassign'}));
$_[0]->{'profs'} = $in{'profs'};
$_[0]->{'execs'} = $in{'execs'};
$_[0]->{'auths'} = $in{'auths'};
$_[0]->{'authassign'} = $in{'authassign'};
$_[0]->{'projects'} = $in{'projects'};
}

