
do 'status-lib.pl';

# list_system_info(&data, &in)
# If enabled, list the state of all monitors
sub list_system_info
{
if (!$config{'sysinfo'}) {
	# Display is disabled
	return ( );
	}
if ($config{'sysinfo_users'} == 0 &&
    $base_remote_user !~ /^(root|admin)$/ ||
    $config{'sysinfo_users'} == 1 &&
    !&foreign_available($module_name)) {
	# Not visible to this user
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
my $can = &foreign_available($module_name) && $access{'edit'};
foreach my $s (@serv) {
	my $stat = &expand_oldstatus($oldstatus{$s->{'id'}});
	my @remotes = &expand_remotes($s);
	my @ups = map { defined($stat->{$_}) ? ( $stat->{$_} ) : ( ) } @remotes;
	my @icons = map { "<img src=".&get_status_icon($_)."> ".
			  &status_to_string($_) } @ups;
	$down += length(grep { $_ == 0 } @ups);
	my $desc = &html_escape($s->{'desc'});
	if ($can) {
		$desc = &ui_link("/$module_name/edit_mon.cgi?id=".
				 &urlize($s->{'id'}), $desc);
		}
	$table .= &ui_columns_row([
		$desc,
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
