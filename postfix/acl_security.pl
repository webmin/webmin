
require 'postfix-lib.pl';
@acl_pages = ("resource", "address_rewriting", "aliases", "general",
	      "canonical", "virtual", "transport", "relocated", "header","body",
	      "bcc", "dependent", "local_delivery", "smtpd", "sasl", "client",
	      "smtp", "rate", "debug", "ldap",
	      "master", "startstop", "mailq", "postfinger", "manual");

# Print the form for security options of postfix module
sub acl_security_form
{
local $o;
foreach $o (@acl_pages) {
	print &ui_table_row($text{'acl_'.$o},
			    &ui_yesno_radio($o, $_[0]->{$o} ? 1 : 0));
	}
print &ui_table_row($text{'acl_dir'},
		    &ui_textbox("dir", $_[0]->{'dir'}, 50));
}


# acl_security_save(&options)
# Parse the form for security options for the postfix module
sub acl_security_save
{
local $o;
foreach $o (@acl_pages) {
	$_[0]->{$o} = $in{$o};
	}
$_[0]->{'dir'} = $in{'dir'};
}


