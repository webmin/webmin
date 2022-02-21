
do 'bandwidth-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
my ($o) = @_;
print &ui_table_row($text{'acl_setup'},
	&ui_yesno_radio("setup", $o->{'setup'}));
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
my ($o) = @_;
$o->{'setup'} = $in{'setup'};
}

