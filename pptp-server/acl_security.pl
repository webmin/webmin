
require 'pptp-server-lib.pl';
@acl_options = ("conf", "options", "secrets", "conns", "stop", "apply");

# acl_security_form(&options)
# Output HTML for editing security options for the pptp-server module
sub acl_security_form
{
foreach my $a (@acl_options) {
	print &ui_table_row($text{'acl_'.$a},
		&ui_yesno_radio($a, $_[0]->{$a}));
	}
}

# acl_security_save(&options)
# Parse the form for security options for the pptp-server module
sub acl_security_save
{
foreach my $a (@acl_options) {
	$_[0]->{$a} = $in{$a};
	}
}
