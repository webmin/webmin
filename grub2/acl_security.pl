use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';

do 'grub2-lib.pl';

our (%in, %text);

# acl_security_form(&options)
# Outputs HTML for editing security options for the GRUB 2 module.
sub acl_security_form
{
my ($o) = @_;
print &ui_table_span(&ui_tag('b', &html_escape($text{'acl_section_view'})));
# View is separated because it controls whether the module can be entered.
foreach my $a (qw(view)) {
	print &ui_table_row($text{'acl_'.$a},
			    &ui_yesno_radio($a, &grub2_check_acl($a, $o)), 3);
	}
print &ui_table_hr();
print &ui_table_span(&ui_tag('b', &html_escape($text{'acl_section_change'})));
# Change permissions modify GRUB configuration without granting install rights.
foreach my $a (qw(edit security apply runtime)) {
	print &ui_table_row($text{'acl_'.$a},
			    &ui_yesno_radio($a, &grub2_check_acl($a, $o)), 3);
	}
print &ui_table_hr();
print &ui_table_span(&ui_tag('b', &html_escape($text{'acl_section_admin'})));
# Admin permissions expose direct file editing, backup, and boot-loader install.
foreach my $a (qw(manual install backup)) {
	print &ui_table_row($text{'acl_'.$a},
			    &ui_yesno_radio($a, &grub2_check_acl($a, $o)), 3);
	}
}

# acl_security_save(&options)
# Parses the form for security options for the GRUB 2 module.
sub acl_security_save
{
my ($o) = @_;
foreach my $a (&grub2_acl_keys()) {
	# Missing checkbox/radio values fall back to denied.
	$o->{$a} = $in{$a} || 0;
	}
}

1;
