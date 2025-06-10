
require 'pap-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the pap module
sub acl_security_form
{
my ($o) = @_;

print &u_table_row($text{'acl_pages'},
    &ui_checkbox('mgetty', 1, $text{'mgetty_title'}, $o->{'mgetty'})."<br>\n".
    &ui_checkbox('options', 1, $text{'options_title'}, $o->{'options'})."<br>\n".
    &ui_checkbox('dialin', 1, $text{'dialin_title'}, $o->{'dialin'})."<br>\n".
    &ui_checkbox('secrets', 1, $text{'secrets_title'}, $o->{'secrets'})."<br>\n".
    &ui_checkbox('sync', 1, $text{'sync_title'}, $o->{'sync'}), 3);

print &ui_table_row($text{'acl_direct'},
	&ui_yesno_radio("direct", $o->{'direct'}));
}

# acl_security_save(&options)
# Parse the form for security options for the squid module
sub acl_security_save
{
my ($o) = @_;

foreach $a ('mgetty', 'options', 'dialin', 'secrets', 'sync') {
	$o->{$a} = $in{$a};
	}
$o->{'direct'} = $in{'direct'};
}

