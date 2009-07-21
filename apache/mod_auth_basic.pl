# mod_auth_basic.pl
# Defines editors for basic authentication directives

sub mod_auth_basic_directives
{
local($rv);
$rv = [ [ 'AuthBasicAuthoritative', 0, 4, 'directory htaccess' ],
	[ 'AuthBasicProvider', 0, 4, 'directory htaccess' ],
      ];
return &make_directives($rv, $_[0], "mod_auth_basic");
}

sub edit_AuthBasicAuthoritative
{
return (1, $text{'mod_auth_basic_pass'},
       &choice_input($_[0]->{'value'}, "AuthBasicAuthoritative", "",
       "$text{'yes'},off", "$text{'no'},on", "$text{'default'},") );
}
sub save_AuthBasicAuthoritative
{
return &parse_choice("AuthBasicAuthoritative", "");
}

sub edit_AuthBasicProvider
{
return (1, $text{'mod_auth_basic_prov'},
	&ui_select("AuthBasicProvider", $_[0] ? $_[0]->{'words'} : [ ],
		   [ [ "file", $text{'mod_auth_basic_file'} ],
		     [ "dbm", $text{'mod_auth_basic_dbm'} ] ],
		   3, 1, 1));
}
sub save_AuthBasicProvider
{
local $p = $in{'AuthBasicProvider'};
return ( $p ? [ join(" ", split(/\0/, $p)) ] : [ ] );
}
