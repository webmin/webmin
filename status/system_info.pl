
do 'status-lib.pl';

# list_system_info(&data, &in)
# If enabled, list the state of all monitors
sub list_system_info
{
if (!$config{'sysinfo'}) {
	# Display is disabled
	return ( );
	}
my @serv = &list_services();
if (!@serv) {
	# Nothing to show
	return ( );
	}
my %oldstatus;
if (!&read_file($oldstatus_file, \%oldstatus)) {
	# Collection not done yet
	return ( );
	}
my $table = &ui_columns_start([ $text{'info_desc'}, $text{'index_host'},
				$text{'info_last'} ]);
my $down = 0;
foreach my $s (@serv) {
	my $stat = &expand_oldstatus($oldstatus{$s->{'id'}});
	my @remotes = &expand_remotes($s);
	my @ups = map { defined($stat->{$_}) ? ( $stat->{$_} ) : ( ) } @remotes;
	my @icons = map { "<img src=".&get_status_icon($_)."> ".
			  &status_to_string($_) } @ups;
	$down += length(grep { $_ == 0 } @ups);
	$table .= &ui_columns_row([
		&html_escape($s->{'desc'}),
		&nice_remotes($s),
		join("", @icons),
		]);
	}
$table .= &ui_columns_end();

return ( { 'type' => 'html',
	   'desc' => $text{'info_title'},
	   'open' => $down ? 1 : 0,
	   'id' => $module_name.'_services',
	   'html' => $table } );
}
