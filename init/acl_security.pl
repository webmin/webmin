
require 'init-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the init module
sub acl_security_form
{
my ($o) = @_;

my $msg = $config{'local_script'} ? $text{'acl_script'} : $text{'acl_actions'};
my @opts = ( [ 1, $text{'yes'} ] );
if (!$config{'local_script'}) {
	push(@opts, [ 2, $text{'acl_runonly'} ]);
	}
push(@opts, [ 0, $text{'no'} ]);
print &ui_table_row($msg,
	&ui_radio("bootup", $o->{'bootup'}, \@opts));

print &ui_table_row($text{'acl_reboot'},
	&ui_yesno_radio("reboot", $o->{'reboot'}));

print &ui_table_row($text{'acl_shutdown'},
	&ui_yesno_radio("shutdown", $o->{'shutdown'}));
}

# acl_security_save(&options)
# Parse the form for security options for the init module
sub acl_security_save
{
my ($o) = @_;
$o->{'bootup'} = $in{'bootup'};
$o->{'reboot'} = $in{'reboot'};
$o->{'shutdown'} = $in{'shutdown'};
}

