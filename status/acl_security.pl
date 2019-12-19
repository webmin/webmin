
do 'status-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the status module
sub acl_security_form
{
my ($o) = @_;
print &ui_table_row($text{'acl_edit'},
	&ui_yesno_radio("edit", $o->{'edit'}));

print &ui_table_row($text{'acl_sched'},
	&ui_yesno_radio("sched", $o->{'sched'}));
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
my ($o) = @_;
$o->{'edit'} = $in{'edit'};
$o->{'sched'} = $in{'sched'};
}

