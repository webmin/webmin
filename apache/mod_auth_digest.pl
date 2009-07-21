# mod_auth_digest.pl
# Defines editors for digest authentication directives

sub mod_auth_digest_directives
{
local($rv);
$rv = [ [ 'AuthDigestAuthoritative', 0, 4, 'directory htaccess' ],
	[ 'AuthDigestProvider', 0, 4, 'directory htaccess' ],
	[ 'AuthDigestAlgorithm', 0, 4, 'directory htaccess' ],
      ];
return &make_directives($rv, $_[0], "mod_auth_digest");
}

sub edit_AuthDigestAuthoritative
{
return (1, $text{'mod_auth_digest_pass'},
       &choice_input($_[0]->{'value'}, "AuthDigestAuthoritative", "",
       "$text{'yes'},off", "$text{'no'},on", "$text{'default'},") );
}
sub save_AuthDigestAuthoritative
{
return &parse_choice("AuthDigestAuthoritative", "");
}

sub edit_AuthDigestProvider
{
return (1, $text{'mod_auth_digest_prov'},
	&ui_select("AuthDigestProvider", $_[0] ?  $_[0]->{'words'} : [ ],
		   [ [ "file", $text{'mod_auth_basic_file'} ],
		     [ "dbm", $text{'mod_auth_basic_dbm'} ] ],
		   3, 1, 1));
}
sub save_AuthDigestProvider
{
local $p = $in{'AuthDigestProvider'};
return ( $p ? [ join(" ", split(/\0/, $p)) ] : [ ] );
}

sub edit_AuthDigestAlgorithm
{
return (1, $text{'mod_auth_digest_al'},
       &choice_input($_[0]->{'value'}, "AuthDigestAlgorithm", "",
       "MD5", "MD5-sess", "$text{'default'},") );
}
sub save_AuthDigestAlgorithm
{
return &parse_choice("AuthDigestAlgorithm", "");
}

sub edit_AuthDigestDomain
{
return (2,
	$text{'mod_auth_digest_domain'},
	&opt_input($_[0]->{'value'}, "AuthDigestDomain", $text{'core_default'}, 50));
}
sub save_AuthDigestDomain
{
return &parse_opt("AuthDigestDomain", '\S',
		  $text{'mod_auth_digest_edomain'});
}

