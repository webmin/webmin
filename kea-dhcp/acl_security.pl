use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';

require 'kea-dhcp-lib.pl'; ## no critic

our (%in, %text);

# acl_security_form(&options)
# Output HTML for editing security options for the Kea DHCP module
sub acl_security_form
{
my ($o) = @_;

# Keep read-only capabilities separate from actions that change files or daemon
# state, matching the way the module's tabs and buttons are gated.
print ui_table_span(&ui_tag('b', &html_escape($text{'acl_section_view'})));
foreach my $a (qw(dhcp4 dhcp6 ddns services runtime)) {
	print ui_table_row($text{'acl_'.$a},
			   ui_yesno_radio($a, $o->{$a}), 3);
	}
print ui_table_hr();
print ui_table_span(&ui_tag('b', &html_escape($text{'acl_section_change'})));
foreach my $a (qw(edit4 edit6 editddns manual apply install)) {
	print ui_table_row($text{'acl_'.$a},
			   ui_yesno_radio($a, $o->{$a}), 3);
	}
}

# acl_security_save(&options)
# Parse the form for security options for the Kea DHCP module
sub acl_security_save
{
my ($o) = @_;

foreach my $a (qw(dhcp4 dhcp6 ddns services runtime edit4 edit6 editddns
		  manual apply install)) {
	$o->{$a} = $in{$a} || 0;
	}
}

1;
