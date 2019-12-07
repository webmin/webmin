
require 'proc-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the proc module
sub acl_security_form
{
my ($o) = @_;

# Run as user
my $u = $o->{'uid'} < 0 ? undef : getpwuid($o->{'uid'});
print &ui_table_row($text{'acl_manage'},
	&ui_radio("uid_def", $_[0]->{'uid'} < 0 ? 1 : 0,
		  [ [ 1, $text{'acl_manage_def'} ],
		    [ 0, &ui_user_textbox("uid", $u) ] ]), 3);

# Who can be managed
if (!defined($o->{'users'})) {
	$o->{'users'} = $o->{'uid'} < 0 ? "x" :
			$o->{'uid'} == 0 ? "*" : getpwuid($o->{'uid'});
	}
my $who = $o->{'users'} eq "x" ? 1 :
	  $o->{'users'} eq "*" ? 0 : 2;
print &ui_table_row($text{'acl_who'},
	&ui_radio("who", $who,
		[ [ 0, $text{'acl_who0'}."<br>\n" ],
		  [ 1, $text{'acl_who1'}."<br>\n" ],
		  [ 2, $text{'acl_who2'} ] ])." ".
		       &ui_textbox("users", $who == 2 ? $_[0]->{'users'} : "",
				   40), 3);

# Can do stuff to processes?
print &ui_table_row($text{'acl_edit'},
	&ui_yesno_radio("edit", $o->{'edit'}), 3);

# Can run commands?
print &ui_table_row($text{'acl_run'},
	&ui_yesno_radio("run", $o->{'run'}), 3);

# Can see other processes?
print &ui_table_row($text{'acl_only'},
	&ui_yesno_radio("only", $o->{'only'}), 3);
}

# acl_security_save(&options)
# Parse the form for security options for the proc module
sub acl_security_save
{
my ($o) = @_;
$o->{'uid'} = $in{'uid_def'} ? -1 : getpwnam($in{'uid'});
$o->{'edit'} = $in{'edit'};
$o->{'run'} = $in{'run'};
$o->{'only'} = $in{'only'};
$o->{'users'} = $in{'who'} == 0 ? "*" :
		   $in{'who'} == 1 ? "x" : $in{'users'};
}

