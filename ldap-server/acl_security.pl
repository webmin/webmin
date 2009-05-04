
do 'ldap-server-lib.pl';
@acl_functions = ( &get_config_type() == 2 ? 'ldif' : 'slapd',
		   'schema', 'acl', 'browser', 'create', 'start', 'apply' );

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
foreach my $f (@acl_functions) {
	print &ui_table_row($text{'acl_'.$f},
		&ui_yesno_radio($f, $_[0]->{$f}));
	}
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
foreach my $f (@acl_functions) {
	$_[0]->{$f} = $in{$f};
	}
}

