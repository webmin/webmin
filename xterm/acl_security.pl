
require 'xterm-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the xterm module
sub acl_security_form
{
my ($o) = @_;

print &ui_table_row($text{'acl_user'},
	&ui_opt_textbox("user", $o->{'user'} eq '*' ? undef : $o->{'user'},
			20, $text{'acl_sameuser'}));

if ($o->{'user'} eq "*" || 
   ($o->{'user'} eq "root" && $remote_user ne $o->{'user'})) {
	print &ui_table_row($text{'acl_sudoenforce'},
		&ui_yesno_radio("sudoenforce",
			$o->{'sudoenforce'} == 1 ? 1 : 0));
	}
else {
	print &ui_hidden("sudoenforce", $o->{'sudoenforce'});
	}
}

sub acl_security_save
{
my ($o) = @_;

$o->{'user'} = $in{'user_def'} ? '*' : $in{'user'};
$o->{'sudoenforce'} = $in{'sudoenforce'} ? 1 : 0;
}
