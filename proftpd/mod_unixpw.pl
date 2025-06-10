# mod_unixpw.pl

sub mod_unixpw_directives
{
local $rv = [
	[ 'AuthUserFile', 0, 6, 'virtual global', 1.11 ],
	[ 'AuthGroupFile', 0, 6, 'virtual global', 1.11 ],
	[ 'AuthPAMAuthoritative', 0, 6, 'virtual global', 1.20 ],
	[ 'PersistentPasswd', 0, 6, 'root', 1.15 ]
	];
return &make_directives($rv, $_[0], "mod_unixpw");
}

sub edit_AuthUserFile
{
return (2, $text{'mod_unixpw_ufile'},
	&opt_input($_[0]->{'value'}, "AuthUserFile", $text{'mod_unixpw_none'},
		   50, &file_chooser_button("AuthUserFile")));
}
sub save_AuthUserFile
{
$in{'AuthUserFile_def'} || -r $in{'AuthUserFile'} ||
	&error($text{'mod_unixpw_eufile'});
return &parse_opt("AuthUserFile");
}

sub edit_AuthGroupFile
{
return (2, $text{'mod_unixpw_gfile'},
	&opt_input($_[0]->{'value'}, "AuthGroupFile", $text{'mod_unixpw_none'},
		   50, &file_chooser_button("AuthGroupFile")));
}
sub save_AuthGroupFile
{
$in{'AuthGroupFile_def'} || -r $in{'AuthGroupFile'} ||
	&error($text{'mod_unixpw_egfile'});
return &parse_opt("AuthGroupFile");
}

sub edit_AuthPAMAuthoritative
{
return (1, $text{'mod_unixpw_pam'},
	&choice_input($_[0]->{'value'}, "AuthPAMAuthoritative", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_AuthPAMAuthoritative
{
return &parse_choice("AuthPAMAuthoritative", "");
}

sub edit_PersistentPasswd
{
return (1, $text{'mod_unixpw_persist'},
	&choice_input($_[0]->{'value'}, "PersistentPasswd", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_PersistentPasswd
{
return &parse_choice("PersistentPasswd", "");
}

