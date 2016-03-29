
use strict;
use warnings;
do 'change-user-lib.pl';
our (%text, %in);

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
my ($o) = @_;
print &ui_table_row($text{'acl_lang'},
	&ui_yesno_radio("lang", $o->{'lang'}));

print &ui_table_row($text{'acl_theme'},
	&ui_yesno_radio("theme", $o->{'theme'}));

print &ui_table_row($text{'acl_pass'},
	&ui_yesno_radio("pass", $o->{'pass'}));
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
my ($o) = @_;
$o->{'lang'} = $in{'lang'};
$o->{'theme'} = $in{'theme'};
$o->{'pass'} = $in{'pass'};
}

