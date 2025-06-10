# mod_authn_dbm.pl
# Defines editors for user text-file authentication directives

sub mod_authn_dbm_directives
{
local($rv);
$rv = [ [ 'AuthDBMUserFile', 0, 4, 'directory htaccess' ],
	[ 'AuthDBMType', 0, 4, 'directory htaccess', 2.030, -1 ] ];
return &make_directives($rv, $_[0], "mod_authn_dbm");
}

sub edit_AuthDBMUserFile
{
return (2, $text{'mod_auth_dbm_ufile'},
       &opt_input($_[0]->{'value'}, "AuthDBMUserFile", $text{'default'}, 45).
       &file_chooser_button("AuthDBMUserFile", 0));
}
sub save_AuthDBMUserFile
{
$in{'AuthDBMUserFile_def'} || &allowed_auth_file($in{'AuthDBMUserFile'}) ||
        &error($text{'mod_auth_eudir'});
return &parse_opt("AuthDBMUserFile", '^\S+$', $text{'mod_auth_dbm_eufile'});
}

sub edit_AuthDBMType
{
return (1, $text{'mod_auth_dbm_type'},
	&select_input($_[0]->{'value'}, "AuthDBMType", "",
		      "$text{'default'},", "GDBM,GDBM", "SDBM,SDBM",
					   "NDBM,NDBM", "DB,DB",
		      "$text{'mod_auth_dbm_default'},default"));
}
sub save_AuthDBMType
{
return &parse_select("AuthDBMType", "");
}


