
do 'firewall-lib.pl';
@acl_features = ("newchain", "delchain", "policy", "apply", "unapply", "bootup", "setup", "cluster");

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
my ($o) = @_;

# Show editable tables
my $tables = "";
foreach $t (@known_tables) {
	$tables .= &ui_checkbox($t, 1, $text{'index_table_'.$t},
				$o->{$t})."<br>\n";
	}
print &ui_table_row($text{'acl_tables'}, $tables, 3);

# Show allowed target types
print &ui_table_row($text{'acl_jumps'},
	&ui_opt_textbox("jumps", $o->{'jumps'}, 40, $text{'acl_jall'}), 3);

# Show bootup/apply options
foreach my $f (@acl_features) {
	print &ui_table_row($text{'acl_'.$f},
		&ui_yesno_radio($f, $o->{$f}));
	}
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
my ($o) = @_;

foreach my $t (@known_tables) {
	$o->{$t} = $in{$t};
	}
foreach my $f (@acl_features) {
	$o->{$f} = $in{$f};
	}
$o->{'jumps'} = $in{'jumps_def'} ? undef : $in{'jumps'};
}

