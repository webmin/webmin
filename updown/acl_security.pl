
require 'updown-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the updown module
sub acl_security_form
{
my ($o) = @_;

print &ui_table_row($text{'acl_upload'},
	&ui_yesno_radio("upload", $o->{'upload'}), 3);

print &ui_table_row($text{'acl_max'},
	&ui_opt_textbox("max", $o->{'max'}, 8,  $text{'acl_unlim'})." ".
	$text{'acl_b'}, 3);

print &ui_table_row($text{'acl_download'},
	&ui_radio("download", $o->{'download'},
		  [ [ 1, $text{'yes'} ],
		    [ 2, $text{'acl_nosched'} ],
		    [ 0, $text{'no'} ] ]), 3);

my $download_address_mode = $o->{'download_address_mode'} || 'public';
print &ui_table_row(
	$text{'acl_download_addresses'} .
		&ui_help($text{'acl_download_addresses_desc'}),
	&ui_radio_table(
		"download_address_mode", $download_address_mode,
		[ [ 'public', $text{'acl_download_public'} ],
		  [ 'listed', $text{'acl_download_listed'},
		    &ui_textarea(
			"download_allowed_addresses",
			join("\n", split(/\s+/,
				$o->{'download_allowed_addresses'})),
			4, 50) ],
		  [ 'all', $text{'acl_download_all'} ] ]),
	3);

print &ui_table_row($text{'acl_users'},
	&ui_radio_table("mode", $o->{'mode'},
		[ [ 0, $text{'acl_all'} ],
		  [ 3, $text{'acl_this'} ],
		  [ 1, $text{'acl_only'}, &ui_users_textbox("userscan", $o->{'mode'} == 1 ? $o->{'users'} : "") ],
		  [ 2, $text{'acl_except'}, &ui_users_textbox("userscannot", $o->{'mode'} == 2 ? $o->{'users'} : "") ]
		]), 3);

print &ui_table_row($text{'acl_dirs'},
	&ui_textarea("dirs", join("\n", split(/\s+/, $o->{'dirs'})), 3, 80).
	"<br>\n".
	&ui_checkbox("home", 1, $text{'acl_home'}, $o->{'home'}), 3);

print &ui_table_row($text{'acl_fetch'},
	&ui_yesno_radio("fetch", $o->{'fetch'}), 3);
}

# acl_security_save(&options)
# Parse the form for security options for the cron module
sub acl_security_save
{
my ($o) = @_;
$o->{'upload'} = $in{'upload'};
$o->{'max'} = $in{'max_def'} ? undef : $in{'max'};
$o->{'download'} = $in{'download'};
my $download_address_mode = $in{'download_address_mode'};
$download_address_mode = 'public'
	if ($download_address_mode !~ /^(public|listed|all)$/);
$o->{'download_address_mode'} = $download_address_mode;
$o->{'download_allowed_addresses'} = join(" ",
	split(/\s+/, $in{'download_allowed_addresses'}));
$o->{'mode'} = $in{'mode'};
$o->{'users'} = $in{'mode'} == 0 || $in{'mode'} == 3 ? "" :
		   $in{'mode'} == 1 ? $in{'userscan'}
				    : $in{'userscannot'};
local @dirs = split(/\s+/, $in{'dirs'});
map { s/\/+/\//g } @dirs;
map { s/([^\/])\/+$/$1/ } @dirs;
$o->{'dirs'} = join(" ", @dirs);
$o->{'home'} = $in{'home'};
$o->{'fetch'} = $in{'fetch'};
}
