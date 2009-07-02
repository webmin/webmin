
require 'phpini-lib.pl';
do '../ui-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the file module
sub acl_security_form
{
local ($o) = @_;
print &ui_table_row($text{'acl_global'},
		    &ui_yesno_radio("global", $o->{'global'}));
print &ui_table_row($text{'acl_anyfile'},
		    &ui_yesno_radio("anyfile", $o->{'anyfile'}));
print &ui_table_row($text{'acl_manual'},
		    &ui_yesno_radio("manual", $o->{'manual'}));

print &ui_table_row($text{'acl_inis'},
	    &ui_textarea("inis", join("\n", split(/\t+/, $o->{'php_inis'})),
			 5, 70), 3);

print &ui_table_row($text{'acl_user'},
		    &ui_user_textbox("user", $o->{'user'}));
}

# acl_security_save(&options)
# Parse the form for security options for the file module
sub acl_security_save
{
local ($o) = @_;
$o->{'global'} = $in{'global'};
$o->{'anyfile'} = $in{'anyfile'};
$o->{'manual'} = $in{'manual'};
$o->{'php_inis'} = join("\t", split(/\n/, $in{'inis'}));
$o->{'user'} = $in{'user'};
}

