# mod_authz_dbm.pl
# Defines editors for user text-file authentication directives

sub mod_authz_dbm_directives
{
local($rv);
$rv = [ [ 'AuthDBMGroupFile', 0, 4, 'directory htaccess' ],
	[ 'AuthzDBMAuthoritative', 0, 4, 'directory htaccess' ],
	[ 'AuthzDBMType', 0, 4, 'directory htaccess', 2.030, -1 ] ];
return &make_directives($rv, $_[0], "mod_authz_dbm");
}

sub edit_AuthDBMGroupFile
{
return (2, $text{'mod_auth_dbm_gfile'},
       &opt_input($_[0]->{'value'}, "AuthDBMGroupFile", $text{'default'}, 45).
       &file_chooser_button("AuthDBMGroupFile", 0));
}
sub save_AuthDBMGroupFile
{
$in{'AuthDBMGroupFile_def'} || &allowed_auth_file($in{'AuthDBMGroupFile'}) ||
        &error($text{'mod_auth_egdir'});
return &parse_opt("AuthDBMGroupFile", '^\S+$', $text{'mod_auth_dbm_egfile'});
}

sub edit_AuthzDBMAuthoritative
{
return (2, $text{'mod_auth_dbm_gpass'},
       &choice_input($_[2]->{'value'}, "AuthzDBMAuthoritative", "",
       "$text{'yes'},off", "$text{'no'},on", "$text{'default'},"));
}
sub save_AuthzDBMAuthoritative
{
return &parse_choice("AuthzDBMAuthoritative", "");
}

sub edit_AuthzDBMType
{
return (1, $text{'mod_auth_dbm_gtype'},
	&select_input($_[0]->{'value'}, "AuthzDBMType", "",
		      "$text{'default'},", "GDBM,GDBM", "SDBM,SDBM",
					   "NDBM,NDBM", "DB,DB",
		      "$text{'mod_auth_dbm_default'},default"));
}
sub save_AuthzDBMType
{
return &parse_select("AuthzDBMType", "");
}


