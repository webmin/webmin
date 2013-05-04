
do 'minecraft-lib.pl';

# status_monitor_list()
# Return a list of supported monitor types
sub status_monitor_list
{
return ( [ "minecraft_up", $text{'monitor_up'} ],
	 [ "minecraft_latest", $text{'monitor_latest'} ] );
}

# status_monitor_status(type, &monitor, from-ui)
# Check the drive status
sub status_monitor_status
{
my ($type, $monitor, $fromui) = @_;
if ($type eq "minecraft_up") {
	# Check if server is running and can reply to commands
	if (!&is_minecraft_server_running()) {
		return { 'up' => 0,
			 'desc' => $text{'monitor_down'} };
		}
	my $out = &execute_minecraft_command("/seed", 0, 5);
	if ($out !~ /Seed:\s+[0-9\-]+/i) {
		return { 'up' => 0,
			 'desc' => $text{'monitor_noreply'} };
		}
	return { 'up' => 1 };
	}
elsif ($type eq "minecraft_latest") {
	# Compare version with latest available to download
	&update_last_check();
	if ($config{'last_size'}) {
		my $jar = $config{'minecraft_jar'} ||
			  $config{'minecraft_dir'}."/"."minecraft_server.jar";
		my @st = stat($jar);
		if (@st && $st[7] != $config{'last_size'}) {
			return { 'up' => 0,
				 'desc' => $text{'monitor_newversion'} };
			}
		elsif (!@st) {
			return { 'up' => -1,
				 'desc' => &text('monitor_nojar', $jar) };
			}
		}
	return { 'up' => 1 };
	}
else {
	return { 'up' => -1,
		 'desc' => $text{'monitor_notype'} };
	}
}

# status_monitor_dialog(type, &monitor)
# Return form for selecting a drive
sub status_monitor_dialog
{
return undef;
}

# status_monitor_parse(type, &monitor, &in)
# Parse form for selecting a rule
sub status_monitor_parse
{
}

1;

