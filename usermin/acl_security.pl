
require 'usermin-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the usermin module
sub acl_security_form
{
my ($o) = @_;
print &ui_table_row($text{'acl_icons'},
	&ui_select("icons", [ keys %$o ],
		   [ map { [ $_, $text{$_."_title"} ] } &get_icons() ],
		   10, 1));

print &ui_table_row($text{'acl_mods'},
	&ui_radio("mods_def", $o->{'mods'} eq '*' ? 1 : 0,
		  [ [ 1, $text{'acl_all'} ],
		    [ 0, $text{'acl_sel'} ] ])."<br>\n".
	&ui_select("mods", [ split(/\s+/, $o->{'mods'}) ],
		   [ map { [ $_->{'dir'}, $_->{'desc'} ] } &list_modules() ],
		   10, 1));

print &ui_table_row($text{'acl_stop'},
	&ui_yesno_radio("stop", $o->{'stop'}));

print &ui_table_row($text{'acl_bootup'},
	&ui_yesno_radio("bootup", $o->{'bootup'}));
}

# acl_security_save(&options)
# Parse the form for security options for the usermin module
sub acl_security_save
{
my ($o) = @_;
my %icons = map { $_, 1 } split(/\0/, $in{'icons'});
foreach my $i (&get_icons()) {
	$o->{$i} = $icons{$i};
	}
$o->{'mods'} = $in{'mods_def'} ? "*" : join(" ", split(/\0/, $in{'mods'}));
$o->{'stop'} = $in{'stop'};
$o->{'bootup'} = $in{'bootup'};
}

sub get_icons
{
return ( "access" ,"bind" ,"ui" ,"umods" ,"os" ,"lang" ,"upgrade" ,"session" ,"assignment" ,"categories" ,"themes", "referers", "anon", "ssl" ,"configs" ,"acl" ,"restrict" ,"users" ,"defacl", "sessions", "blocked", "advanced" );
}

