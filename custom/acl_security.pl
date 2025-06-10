
require 'custom-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the custom module
sub acl_security_form
{
my ($o) = @_;
my $mode = $o->{'cmds'} eq '*' ? 1 :
	   $o->{'cmds'} =~ /^\!/ ? 2 : 0;
my @cmds = &sort_commands(&list_commands());
print &ui_table_row($text{'acl_cmds'},
	&ui_radio("cmds_def", $mode,
		  [ [ 1, $text{'acl_call'} ],
		    [ 0, $text{'acl_csel'} ],
		    [ 2, $text{'acl_cexcept'} ] ])."<br>\n".
	&ui_select("cmds",
		   [ split(/\s+/, $o->{'cmds'}) ],
		   [ map { [ $_->{'id'}, $_->{'desc'} ] } @cmds ],
		   10, 1), 3); 

print &ui_table_row($text{'acl_edit'},
	&ui_yesno_radio("edit", $_[0]->{'edit'}));
}

# acl_security_save(&options, &in)
# Parse the form for security options for the custom module
sub acl_security_save
{
my ($o, $in) = @_;
if ($in->{'cmds_def'} == 1) {
	$o->{'cmds'} = "*";
	}
elsif ($in->{'cmds_def'} == 0) {
	$o->{'cmds'} = join(" ", split(/\0/, $in->{'cmds'}));
	}
else {
	$o->{'cmds'} = join(" ", "!", split(/\0/, $in->{'cmds'}));
	}
$o->{'edit'} = $in->{'edit'};
}

