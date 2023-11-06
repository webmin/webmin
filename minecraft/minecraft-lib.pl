# Functions for editing the minecraft config
# XXX plugin manager

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
use WebminCore;
use Time::Local;
use POSIX;
&init_config();
our ($module_root_directory, %text, %gconfig, $root_directory, %config,
     $module_name, $remote_user, $base_remote_user, $gpgpath,
     $module_config_directory, @lang_order_list, @root_directories,
     $module_config_file);
our $history_file = "$module_config_directory/history.txt";
our $download_page_url = "https://www.minecraft.net/en-us/download/server";
our $playtime_dir = "$module_config_directory/playtime";
our $uuid_cache_file = "$module_config_directory/uuids";

&foreign_require("webmin");

# get_minecraft_jar()
# Returns the path to the JAR file
sub get_minecraft_jar
{
if ($config{'minecraft_jar'} && $config{'minecraft_jar'} =~ /^\//) {
	return $config{'minecraft_jar'};
	}
elsif ($config{'minecraft_jar'}) {
	return $config{'minecraft_dir'}."/".$config{'minecraft_jar'};
	}
else {
	return $config{'minecraft_dir'}."/"."minecraft_server.jar";
	}
}

# check_minecraft_server()
# Returns an error message if the Minecraft server is not installed
sub check_minecraft_server
{
-d $config{'minecraft_dir'} ||
	return &text('check_edir', $config{'minecraft_dir'});
my $jar = &get_minecraft_jar();
-r $jar ||
	return &text('check_ejar', $jar);
&has_command($config{'java_cmd'}) ||
	return &text('check_ejava', $config{'java_cmd'});
return undef;
}

# is_minecraft_port_in_use()
# If any server is using the default Minecraft port or looks like it is running
# minecraft_server.jar, return the PID.
sub is_minecraft_port_in_use
{
&foreign_require("proc");
my $port = $config{'port'} || 25565;
my ($pid) = &proc::find_socket_processes("tcp:".$port);
return $pid if ($pid);
my @procs = &proc::list_processes();
my $jar = &get_minecraft_jar();
foreach my $p (@procs) {
	if ($p->{'args'} =~ /^java.*\Q$jar\E/) {
		return $p->{'pid'};
		}
	}
return undef;
}

# is_minecraft_server_running()
# If the minecraft server is running, return the PID
sub is_minecraft_server_running
{
&foreign_require("proc");
my @procs = &proc::list_processes();
my $jar = &get_minecraft_jar();
my $shortjar = $jar;
$shortjar =~ s/^.*\///;
foreach my $p (@procs) {
	if ($p->{'args'} =~ /^\S*\Q$config{'java_cmd'}\E.*\Q$jar\E/) {
		return $p->{'pid'};
		}
	}
return undef;
}

# is_any_minecraft_server_running()
# If the server is runnign for ANY version of Minecraft, return the PID
sub is_any_minecraft_server_running
{
&foreign_require("proc");
my @procs = &proc::list_processes();
my $dir = $config{'minecraft_dir'};
my $jar = &get_minecraft_jar();

# Prefer the default version
foreach my $p (@procs) {
	if ($p->{'args'} =~ /^\S*\Q$config{'java_cmd'}\E.*\Q$jar\E/) {
		my $ver = $jar =~ /([0-9\.]+)\.jar$/ ? $1 : undef;
		return wantarray ? ($p->{'pid'}, $ver, $jar) : $p->{'pid'};
		}
	}

# Look for other versions
foreach my $p (@procs) {
	if ($p->{'args'} =~ /^\S*\Q$config{'java_cmd'}\E.*(\Q$dir\E\S+\.jar)/) {
		my $jar = $1;
		my $ver = $jar =~ /([0-9\.]+)\.jar$/ ? $1 : undef;
		return wantarray ? ($p->{'pid'}, $ver, $jar) : $p->{'pid'};
		}
	}
return wantarray ? ( ) : undef;
}

sub get_minecraft_config_file
{
return $config{'minecraft_dir'}."/server.properties";
}

# get_minecraft_config()
# Parses the config into an array ref of hash refs
sub get_minecraft_config
{
my @rv;
my $fh = "CONFIG";
my $lnum = 0;
&open_readfile($fh, &get_minecraft_config_file()) || return [ ];
while(<$fh>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^([^=]+)=(.*)/) {
		push(@rv, { 'name' => $1,
			    'value' => $2,
			    'line' => $lnum });
		}
	$lnum++;
	}
close($fh);
return \@rv;
}

# find(name, &config)
# Returns all objects with some name in the config
sub find
{
my ($name, $conf) = @_;
my @rv = grep { lc($_->{'name'}) eq lc($name) } @$conf;
return wantarray ? @rv : $rv[0];
}

# find_value(name, &config)
# Returns the values of all objects with some name in the config
sub find_value
{
my ($name, $conf) = @_;
my @rv = map { $_->{'value'} } &find($name, $conf);
return wantarray ? @rv : $rv[0];
}

# save_directive(name, value, &config)
# Update one directive in the config
sub save_directive
{
my ($name, $value, $conf) = @_;
my $old = &find($name, $conf);
my $lref = &read_file_lines(&get_minecraft_config_file());
if ($old && defined($value)) {
	# Update existing line
	$lref->[$old->{'line'}] = $name."=".$value;
	$old->{'value'} = $value;
	}
elsif ($old && !defined($value)) {
	# Delete existing line
	splice(@$lref, $old->{'line'}, 1);
	my $idx = &indexof($old, @$conf);
	splice(@$conf, $idx, 1) if ($idx >= 0);
	foreach my $c (@$conf) {
		if ($c->{'line'} > $old->{'line'}) {
			$c->{'line'}--;
			}
		}
	}
elsif (!$old && defined($value)) {
	# Add new line
	my $n = { 'name' => $name,
		  'value' => $value,
		  'line' => scalar(@$lref) };
	push(@$lref, $name."=".$value);
	push(@$conf, $n);
	}
}

# get_start_command([suffix])
# Returns a command to start the server
sub get_start_command
{
my ($suffix) = @_;
my $jar = &get_minecraft_jar();
my $ififo = &get_input_fifo();
my $rv = "(test -e ".$ififo." || mkfifo ".$ififo.") ; ".
	 "cd ".$config{'minecraft_dir'}." && ".
	 "(tail -f ".$ififo." | ".
	 $config{'java_envs'}." ".
	 &has_command($config{'java_cmd'})." ".
	 $config{'java_args'}." ".
	 " -jar ".$jar." nogui ".
	 $config{'jar_args'}." ".
	 ">> server.out 2>&1 )";
$rv .= " ".$suffix if ($suffix);
if ($config{'unix_user'} ne 'root') {
	$rv = &command_as_user($config{'unix_user'}, 0, $rv);
	}
return $rv;
}

sub get_input_fifo
{
return $config{'minecraft_dir'}."/input.fifo";
}

# start_minecraft_server()
# Launch the minecraft server in the background
sub start_minecraft_server
{
# Mark EULA as accepted
my $eula = $config{'minecraft_dir'}."/eula.txt";
my $lref = &read_file_lines($eula);
my $changed = 0;
foreach my $l (@$lref) {
	if ($l =~ /eula=false/) {
		$l =~ s/false/true/;
		$changed++;
		}
	}
if ($changed) {
	&flush_file_lines($eula);
	}
else {
	&unflush_file_lines($eula);
	}

my $cmd = &get_start_command();
my $pidfile = &get_pid_file();
&unlink_file($pidfile);
&system_logged("$cmd &");
sleep(1);
my $pid = &is_minecraft_server_running();
if (!$pid) {
	my $out = &backquote_command(
		"tail -2 ".$config{'minecraft_dir'}."/server.out");
	return $out || "Unknown error - no output produced";
	}
my $fh = "PID";
&open_tempfile($fh, ">$pidfile");
&print_tempfile($fh, $pid."\n");
&close_tempfile($fh);
&set_ownership_permissions($config{'unix_user'}, undef, undef, $pidfile);
return undef;
}

# stop_minecraft_server([other-version])
# Kill the server, if running
sub stop_minecraft_server
{
my ($any) = @_;
my $func = $any ? \&is_any_minecraft_server_running
		: \&is_minecraft_server_running;
my $pid = &$func();
$pid || return "Not running!";

# Try graceful shutdown
&send_server_command("/save-all");
&send_server_command("/stop");
for(my $i=0; $i<10; $i++) {
	last if (!&$func());
	sleep(1);
	}

# Clean kill
if (&$func()) {
	kill('TERM', $pid);
	for(my $i=0; $i<10; $i++) {
		last if (!&$func());
		sleep(1);
		}
	}

# Fatal kill
if (&$func()) {
	kill('KILL', $pid);
	}

# Clean up FIFO tailer
my $fpid = int(&backquote_command("fuser ".&get_input_fifo()." 2>/dev/null"));
if ($fpid) {
	kill('TERM', $fpid);
	}
return undef;
}

# send_server_command(command, [no-log])
# Just sends a command to the server
sub send_server_command
{
my ($cmd, $nolog) = @_;
my $ififo = &get_input_fifo();
my $fh = "FIFO";
&open_tempfile($fh, ">$ififo", 1, 1, 1);
&print_tempfile($fh, $cmd."\n");
&close_tempfile($fh);
if (!$nolog) {
	&additional_log('minecraft', 'server', $cmd);
	}
}

# get_minecraft_log_file()
sub get_minecraft_log_file
{
my $newfile = $config{'minecraft_dir'}."/logs/latest.log";
if (-r $newfile) {
	return $newfile;
	}
else {
	return $config{'minecraft_dir'}."/server.log";
	}
}

# execute_minecraft_command(command, [no-log], [wait-time])
# Run a command, and return output from the server log
sub execute_minecraft_command
{
my ($cmd, $nolog, $wait) = @_;
$cmd =~ s/^\///;	# Leading / is now obsolete
$wait ||= 100;
my $logfile = &get_minecraft_log_file();
my $fh = "LOG";
&open_readfile($fh, $logfile);
seek($fh, 0, 2);
my $pos = tell($fh);
&send_server_command($cmd, $nolog);
for(my $i=0; $i<$wait; $i++) {
	select(undef, undef, undef, 0.1);
	my @st = stat($logfile);
	last if ($st[7] > $pos);
	}
my $out;
while(<$fh>) {
	$out .= $_;
	}
close($fh);
return wantarray ? split(/\r?\n/, $out) : $out;
}

# get_command_history()
# Returns the history of commands run
sub get_command_history
{
my $lref = &read_file_lines($history_file);
return @$lref;
}

# save_command_history(&commands)
sub save_command_history
{
my ($cmds) = @_;
my $lref = &read_file_lines($history_file);
@$lref = @$cmds;
&flush_file_lines($history_file);
}

# list_connected_players()
# Returns a list of players currently online
sub list_connected_players
{
my @out = &execute_minecraft_command("/list", 1);
my @rv;
foreach my $l (@out) {
	if ($l !~ /players\s+online:/ && $l =~ /INFO\]:?\s+(\S.*)$/) {
		push(@rv, split(/,\s+/, $1));
		}
	elsif ($l =~ /max\s+\d+\s+players\s+online:\s+(\S.*)/ ||
	       $l =~ /max\s+of\s+\d+\s+players\s+online:\s+(\S.*)/) {
		push(@rv, split(/,\s+/, $1));
		}
	}
return @rv;
}

# get_login_logout_times(player)
# Returns the last login IP, time, X, Y, Z, logout time (if any) and list of
# recent events.
sub get_login_logout_times
{
my ($name) = @_;
my ($ip, $intime, $xx, $yy, $zz, $outtime);
my $logfile = &get_minecraft_log_file();
my @events;
my @files = ( $logfile );
if ($logfile =~ /^(.*)\/latest.log$/) {
	# New server version keeps old rotated log files in gzip format
	my $dir = $1;
	my @extras;
	opendir(DIR, $dir);
	foreach my $f (readdir(DIR)) {
		if ($f =~ /^(\d+\-\d+\-\d+-\d+)\.log\.gz$/) {
			push(@extras, $f);
			}
		}
	closedir(DIR);
	@extras = sort { $a cmp $b } @extras;
	unshift(@files, map { "$dir/$_" } @extras);

	# To avoid reading too much, limit to newest 100k of logs
	my @small;
	my $total = 0;
	foreach my $f (reverse(@files)) {
		push(@small, $f);
		my @st = stat($f);
		$total += $st[7];
		last if ($total > 100000);
		}
	@files = reverse(@small);
	}
foreach my $f (@files) {
	my $fh = "TAIL";
	if ($f =~ /\/latest.log$/) {
		# Latest log, read all of it
		&open_readfile($fh, $f);
		}
	elsif ($f =~ /\.gz$/) {
		# Read whole compressed log
		&open_execute_command($fh, "gunzip -c $f", 1, 1);
		}
	else {
		# Old single log file, read only the last 10k lines
		&open_execute_command($fh, "tail -10000 $f", 1, 1);
		}
	my @tm = localtime(time());
	while(<$fh>) {
		my ($y, $mo, $d, $h, $m, $s, $msg);
		if (/^(\d+)\-(\d+)\-(\d+)\s+(\d+):(\d+):(\d+)\s+\[\S+\]\s+(.*)/) {
			# Old log format
			($y, $mo, $d, $h, $m, $s, $msg) = ($1, $2, $3, $4, $5, $6, $7);
			}
		elsif (/^\[(\d+):(\d+):(\d+)\]\s+\[[^\[]+\]:\s*(.*)/) {
			# New log format
			($h, $m, $s, $msg) = ($1, $2, $3, $4);
			if ($f =~ /\/(\d+)\-(\d+)\-(\d+)/) {
				# Get date from old rotated log
				($y, $mo, $d) = ($1, $2, $3);
				}
			else {
				# Assume latest.log, which is for today
				($y, $mo, $d) = ($tm[5]+1900, $tm[4]+1, $tm[3]);
				}
			}
		else {
			next;
			}
		if ($msg =~ /^\Q$name\E\[.*\/([0-9\.]+):(\d+)\]\s+logged\s+in.*\((\-?[0-9\.]+),\s+(\-?[0-9\.]+),\s+(\-?[0-9\.]+)\)/) {
			# Login message
			$ip = $1;
			($xx, $yy, $zz) = ($3, $4, $5);
			$intime = &parse_log_time($y, $m, $d, $h, $mo, $s);
			}
		elsif ($msg =~ /^\Q$name\E\s+(\[.*\]\s+)?lost/ ||
		       $msg =~ /^Disconnecting\s+\Q$name\E/) {
			# Logout message
			$outtime = &parse_log_time($y, $m, $d, $h, $mo, $s);
			}
		elsif ($msg =~ /^(\S+\s+)?\Q$name\E(\s|\[)/) {
			# Some player event
			push(@events,
			   { 'time' => &parse_log_time($y, $m, $d, $h, $mo, $s),
			     'msg' => $msg });
			}
		}
	close($fh);
	}
return ( $ip, $intime, $xx, $yy, $zz, $outtime, \@events );
}

sub parse_log_time
{
my ($y, $m, $d, $h, $mo, $s) = @_;
return timelocal($s, $m, $h, $d, $mo-1, $y-1900);
}

# item_chooser_button(fieldname)
sub item_chooser_button
{
my ($field) = @_;
return "<input type=button onClick='ifield = document.forms[0].$field; chooser = window.open(\"item_chooser.cgi?item=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=600,height=600\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

# list_minecraft_items()
# Returns a list of hash refs with id and name keys
# CSV generated with :
# items-page-to-csv.pl > items.csv
sub list_minecraft_items
{
my $fh = "ITEMS";
&open_readfile($fh, "$module_root_directory/items.csv");
my @rv;
while(<$fh>) {
	s/\r|\n//g;
	my ($id, $name, $desc) = split(/,/, $_);
	push(@rv, { 'id' => $id,
		    'name' => $name,
		    'desc' => $desc });
	}
close($fh);
return @rv;
}

# list_banned_players()
# Returns a list of players who are banned
sub list_banned_players
{
my @out = &execute_minecraft_command("/banlist", 1);
my @rv;
foreach my $l (@out) {
	if ($l !~ /banned\s+players:/ && $l =~ /INFO\]:?\s+(\S.*)$/) {
		push(@rv, grep { $_ ne "and" } split(/[, ]+/, $1));
		}
	}
return @rv;
}

# list_whitelisted_players()
# Returns a list of players who are whitelisted
sub list_whitelisted_players
{
my @out = &execute_minecraft_command("/whitelist list", 1);
my @rv;
foreach my $l (@out) {
	if ($l !~ /whitelisted\s+players:/ && $l =~ /INFO\]:?\s+(\S.*)$/) {
		push(@rv, grep { $_ ne "and" } split(/[, ]+/, $1));
		}
	}
return @rv;
}

sub get_whitelist_file
{
return $config{'minecraft_dir'}.'/white-list.txt';
}

# list_whitelist_users()
# Returns a list of usernames on the whitelist
sub list_whitelist_users
{
my $lref = &read_file_lines(&get_whitelist_file(), 1);
return @$lref;
}

# save_whitelist_users(&users)
# Update the usernames on the whitelist
sub save_whitelist_users
{
my ($users) = @_;
my $lref = &read_file_lines(&get_whitelist_file());
@$lref = @$users;
&flush_file_lines(&get_whitelist_file());
&set_ownership_permissions($config{'unix_user'}, undef, undef,
			    &get_whitelist_file());
}

sub get_op_file
{
return $config{'minecraft_dir'}.'/ops.txt';
}

# list_op_users()
# Returns a list of usernames on the operator list
sub list_op_users
{
my $lref = &read_file_lines(&get_op_file(), 1);
return @$lref;
}

# save_op_users(&users)
# Update the usernames on the operator list
sub save_op_users
{
my ($users) = @_;
my $lref = &read_file_lines(&get_op_file());
@$lref = @$users;
&flush_file_lines(&get_op_file());
&set_ownership_permissions($config{'unix_user'}, undef, undef,
			    &get_op_file());
}

# list_worlds()
# Returns a list of possible world directories
sub list_worlds
{
my @rv;
foreach my $dat (glob("$config{'minecraft_dir'}/*/level.dat")) {
	$dat =~ /^(.*\/([^\/]+))\/level.dat$/ || next;
	my $path = $1;
	my $name = $2;
	my @players;
	if (-d "$path/players") {
		# Old format
		@players = map { s/^.*\///; s/\.dat$//; $_ }
			       glob("\Q$path\E/players/*");
		}
	if (-d "$path/playerdata" && !@players) {
		# New format (UUID based)
		@players = map { s/^.*\///; s/\.dat$//; $_ }
			       glob("\Q$path\E/playerdata/*");
		@players = map { my $u = $_;
				 &uuid_to_username($u) || $u } @players;
		}
	push(@rv, { 'path' => $path,
		    'name' => $name,
		    'size' => &disk_usage_kb($path)*1024,
		    'lock' => (-r "$path/session.lock"),
		    'players' => \@players });
	}
return @rv;
}

# uuid_to_username(uuid)
# Returns the username with some UUID, by searching logs if needed
sub uuid_to_username
{
my ($uuid) = @_;
my %cache;
&read_file_cached($uuid_cache_file, \%cache);
return $cache{$uuid} if (exists($cache{$uuid}));
my $found = 0;
foreach my $file (&get_minecraft_log_file(),
		  sort { $b cmp $a }
		       glob("$config{'minecraft_dir'}/logs/*.log.gz")) {
	if ($file =~ /\.gz$/) {
		open(LOG, "gunzip -c ".quotemeta($file)." |");
		}
	else {
		open(LOG, $file);
		}
	while(<LOG>) {
		if (/UUID\s+of\s+player\s+(\S+)\s+is\s+(\S+)/) {
			my ($lp, $lu) = ($1, $2);
			if ($lu =~ /^([0-9a-f]{8})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{12})$/) {
				# Convert to new UUID format
				$lu = "$1-$2-$3-$4-$5";
				}
			$cache{$lp} = $lu;
			$cache{$lu} = $lp;
			if ($cache{$uuid}) {
				$found = 1;
				last;
				}
			}
		}
	close(LOG);
	if ($found) {
		&write_file($uuid_cache_file, \%cache);
		last;
		}
	}
# If we got this far, it wasn't found
if (!exists($cache{$uuid})) {
	$cache{$uuid} = "";
	&write_file($uuid_cache_file, \%cache);
	}
return $cache{$uuid};
}

# list_banned_ips()
# Returns an array of banned addresses
sub list_banned_ips
{
my @out = &execute_minecraft_command("/banlist ips", 1);
my @rv;
foreach my $l (@out) {
	if ($l !~ /banned\s+IP\s+addresses:/ && $l =~ /INFO\]:?\s+(\S.*)$/) {
		push(@rv, grep { $_ ne "and" } split(/[, ]+/, $1));
		}
	}
return @rv;
}

# md5_checksum(file)
# Returns a checksum for a file
sub md5_checksum
{
my ($file) = @_;
&has_command("md5sum") || &error("md5sum command not installed!");
return undef if (!-r $file);
my $out = &backquote_command("md5sum ".quotemeta($file));
return $out =~ /^([a-f0-9]+)\s/ ? $1 : undef;
}

# get_pid_file()
# Returns the file in which the server PID is stored
sub get_pid_file
{
return $config{'minecraft_dir'}."/server.pid";
}

# update_init_script_args(&args)
# Updates all Java command-line args in the init script
sub update_init_script_args
{
my ($args) = @_;
my $mode;
&foreign_require("init");
if (defined(&init::get_action_mode)) {
	$mode = &init::get_action_mode($config{'init_name'});
	}
$mode ||= $init::init_mode;

# Find the init script file
my $file;
if ($mode eq "init") {
	$file = &init::action_filename($config{'init_name'});
	}
elsif ($mode eq "upstart") {
	$file = "/etc/init/$config{'init_name'}.conf";
	}
elsif ($mode eq "systemd") {
	my $unit = $config{'init_name'};
	$unit .= ".service" if ($unit !~ /\.service$/);
	$file = &init::get_systemd_root($config{'init_name'})."/".$unit;
	}
elsif ($mode eq "local") {
	$file = "$init::module_config_directory/$config{'init_name'}.sh";
	}
elsif ($mode eq "osx") {
	my $ucfirst = ucfirst($config{'init_name'});
	$file = "$init::config{'darwin_setup'}/$ucfirst/$init::config{'plist'}";
	}
elsif ($mode eq "rc") {
	my @dirs = split(/\s+/, $init::config{'rc_dir'});
	$file = $dirs[$#dirs]."/".$config{'init_name'}.".sh";
	}
else {
	return 0;
	}
return 0 if (!-r $file);	# Not enabled?

# Find and edit the Java command
&lock_file($file);
my $lref = &read_file_lines($file);
my $found = 0;
foreach my $l (@$lref) {
	if ($l =~ /^(.*su.*-c\s+)(.*)/) {
		# May be wrapped in an su command
		my $su = $1;
		my $cmd = &unquotemeta($2);
		if ($cmd =~ /^(.*\Q$config{'java_cmd'}\E)\s+(.*)(-jar.*)/) {
			$cmd = $1." ".$args." ".$3;
			$l = $su.quotemeta($cmd);
			$found = 1;
			}
		}
	elsif ($l =~ /^(.*\Q$config{'java_cmd'}\E)\s+(.*)(-jar.*)/) {
		$l = $1." ".$args." ".$3;
		$found = 1;
		}
	}
&flush_file_lines($file);
&unlock_file($file);

return $found;
}

sub unquotemeta
{
my ($str) = @_;
eval("\$str = \"$str\"");
return $str;
}

# get_server_jar_url()
# Returns the URL for downloading the server JAR file, and optionally the
# latest version number
sub get_server_jar_url
{
my ($host, $port, $page, $ssl) = &parse_http_url($download_page_url);
return undef if (!$host);
my ($out, $err);
&http_download($host, $port, $page, \$out, \$err, undef, $ssl,
	       undef, undef, 5, 0, 1);
return undef if ($err);
$out =~ /"((http|https):[^"]+server\.jar)"/ ||
	return undef;
my $url = $1;
my $ver;
if ($out =~ /minecraft_server\.([0-9\.]+)\.jar/) {
	$ver = $1;
	}
return wantarray ? ($url, $ver) : $url;
}

# check_server_download_size()
# Returns the size in bytes of the minecraft server that is available 
# for download
sub check_server_download_size
{
my ($host, $port, $page, $ssl) = &parse_http_url(&get_server_jar_url());

# Make HTTP connection
my @headers;
push(@headers, [ "Host", $host ]);
push(@headers, [ "User-agent", "Webmin" ]);
push(@headers, [ "Accept-language", "en" ]);
alarm(5);
my $h = &make_http_connection($host, $port, $ssl, "HEAD", $page, \@headers);
alarm(0);
return undef if (!ref($h));

# Read headers
my $line;
($line = &read_http_connection($h)) =~ tr/\r\n//d;
if ($line !~ /^HTTP\/1\..\s+(200)(\s+|$)/) {
	return undef;
	}
my %header;
while(1) {
	$line = &read_http_connection($h);
	$line =~ tr/\r\n//d;
	$line =~ /^(\S+):\s+(.*)$/ || last;
	$header{lc($1)} = $2;
	}

&close_http_connection($h);
return $header{'content-length'};
}

# get_backup_job()
# Returns the webmincron job to backup worlds
sub get_backup_job
{
&foreign_require("webmincron");
my @jobs = &webmincron::list_webmin_crons();
my ($job) = grep { $_->{'module'} eq $module_name &&
		   $_->{'func'} eq "backup_worlds" } @jobs;
return $job;
}

# backup_worlds()
# This function is called by webmincron to perform a backup
sub backup_worlds
{
my ($out, $failed) = &execute_backup_worlds();
&send_backup_email(join("\n", @$out)."\n", $failed);
}

# execute_backup_worlds()
# Run the configured backup, and return output and the failed flag
sub execute_backup_worlds
{
# Get worlds to include
my @allworlds = &list_worlds();
my @worlds;
if ($config{'backup_worlds'}) {
	my %names = map { $_, 1 } split(/\s+/, $config{'backup_worlds'});
	@worlds = grep { $names{$_->{'name'}} } @allworlds;
	}
else {
	@worlds = @allworlds;
	}
if (!@worlds) {
	return (["No worlds were found to backup!"], 1);
	}

# Get destination dir, with strftime
my @tm = localtime(time());
&clear_time_locale();
my $dir = strftime($config{'backup_dir'}, @tm);
&reset_time_locale();

# Create destination dir
if (!-d $dir) {
	if (!&make_dir($dir, 0755)) {
		return (["Failed to create destination directory $dir : $!"],1);
		}
	if ($config{'unix_user'} ne 'root') {
		&set_ownership_permissions($config{'unix_user'}, undef, undef,
					   $dir);
		}
	}

# Find active world
my $conf = &get_minecraft_config();
my $def = &find_value("level-name", $conf);

# Backup each world
my @out;
my $failed = 0;
foreach my $w (@worlds) {
	my $file = "$dir/$w->{'name'}.zip";
	push(@out, "Backing up $w->{'name'} to $file ..");
	if ($w->{'name'} eq $def &&
	    &is_minecraft_server_running()) {
		# World is live, flush state to disk
		&execute_minecraft_command("save-off");
		&execute_minecraft_command("save-all");
		}
	my $out = &backquote_command(
		"cd ".quotemeta($config{'minecraft_dir'})." && ".
	        "zip -r ".quotemeta($file)." ".quotemeta($w->{'name'}));
	my $ex = $?;
	&set_ownership_permissions(undef, undef, 0755, $file);
	if ($w->{'name'} eq $def &&
	    &is_minecraft_server_running()) {
		# Re-enable world writes
		&execute_minecraft_command("save-on");
		}
	my @st = stat($file);
	if (@st && $config{'unix_user'} ne 'root') {
		&set_ownership_permissions($config{'unix_user'}, undef, undef,
					   $file);
		}
	if ($ex) {
		push(@out, " .. ZIP of $w->{'name'} failed : $out");
		$failed++;
		}
	elsif (!@st) {
		push(@out, " .. ZIP of $w->{'name'} produced no output : $out");
		$failed++;
		}
	else {
		push(@out, " .. done (".&nice_size($st[7]).")");
		}
	push(@out, "");
	}
return (\@out, $failed);
}

# send_backup_email(msg, error)
# Sends a backup report email, if configured
sub send_backup_email
{
my ($msg, $err) = @_;
return 0 if (!$config{'backup_email'});
return 0 if ($config{'backup_email_err'} && !$err);
&foreign_require("mailboxes");
&mailboxes::send_text_mail(
	&mailboxes::get_from_address(),
	$config{'backup_email'},
	undef,
	"Minecraft backup ".($err ? "FAILED" : "succeeded"),
	$msg);
}

# level_to_orbs(level)
# Converts a desired level to a number of orbs. From :
# http://www.minecraftwiki.net/wiki/Experience
sub level_to_orbs
{
my ($lvl) = @_;
if ($lvl < 17) {
	return $lvl * 17;
	}
my @xpmap = split(/\s+/,
	"17 292 18 315 19 341 20 370 21 402 22 437 23 475 24 516 ".
	"25 560 26 607 27 657 28 710 29 766 30 825 31 887 32 956 ".
	"33 1032 34 1115 35 1205 36 1302 37 1406 38 1517 39 1635 ".
	"40 1760 41 3147 42 3297 43 3451 44 3608 45 3769 46 3933 ".
	"47 4101 48 4272 49 4447 50 4625");
for(my $i=0; $i<@xpmap; $i+=2) {
	if ($xpmap[$i] == $lvl) {
		return $xpmap[$i+1];
		}
	}
return undef;
}

# get_current_day_usage()
# Returns a hash ref from usernames to total usage over the last day, and
# usage that counts towards any limits
sub get_current_day_usage
{
my $logfile = &get_minecraft_log_file();

# Seek back till we find a day line from a previous day
my @st = stat($logfile);
return { } if (!@st);
my $pos = $st[7];
open(LOGFILE, $logfile);
my @tm = localtime(time());
my $wantday = sprintf("%4.4d-%2.2d-%2.2d", $tm[5]+1900, $tm[4]+1, $tm[3]);
my $lasttime;
while(1) {
	$pos -= 4096;
	$pos = 0 if ($pos < 0);
	seek(LOGFILE, $pos, 0);
	last if ($pos == 0);
	my $dummy = <LOGFILE>;	# Skip partial line
	my $line = <LOGFILE>;
	if ($line =~ /^((\d+)\-(\d+)\-(\d+))/) {
		# Format with the date in it
		if ($1 ne $wantday) {
			# Found a line for another day
			last;
			}
		}
	elsif ($line =~ /^\[((\d+):(\d+):(\d+))\]/) {
		# Format with the time only
		if ($lasttime && ($1 cmp $lasttime) > 0) {
			# Time has gone forwards, meaning its a new day
			last;
			}
		$lasttime = $1;
		}
	}

# Read forwards, looking for logins and logouts for today
my (%rv, %limit_rv);
my (%lastlogin, %limit_lastlogin);
while(my $line = <LOGFILE>) {
	my ($day, $secs);
	if ($line =~ /^((\d+)\-(\d+)\-(\d+))\s+(\d+):(\d+):(\d+)/) {
		# Old log format, which contains the day and time
		$day = $1;
		$day eq $wantday || next;
		$secs = $5*60*60 + $6*60 + $7;
		}
	elsif ($line =~ /^\[(\d+):(\d+):(\d+)\]/) {
		# New log format, assume that it is for the current day
		$day = $wantday;
		$secs = $1*60*60 + $2*60 + $3;
		}
	if ($line =~ /\s(\S+)\[.*\/([0-9\.]+):(\d+)\]\s+logged\s+in\s/) {
		# Login by a user
		my ($u, $ip) = ($1, $2);
		$lastlogin{$u} = $secs;
		if (&limit_user($ip, $u, $day)) {
			$limit_lastlogin{$u} = $secs;
			}
		}
	elsif ($line =~ /\s(\S+)(\s*\[[^\]]+\])?\s+lost\s+connection/) {
		# Logout .. count time
		if (defined($lastlogin{$1})) {
			# Add time from last login
			$rv{$1} += $secs - $lastlogin{$1};
			delete($lastlogin{$1});
			}
		if (defined($limit_lastlogin{$1})) {
			# Also for login that counts towards limits
			$limit_rv{$1} += $secs - $limit_lastlogin{$1};
			delete($limit_lastlogin{$1});
			}
		}
	}
close(LOGFILE);

# Add any active sessions
my $now = $tm[2]*60*60 + $tm[1]*60 + $tm[0];
foreach my $u (keys %lastlogin) {
	$rv{$u} += $now - $lastlogin{$u};
	}
foreach my $u (keys %limit_lastlogin) {
	$limit_rv{$u} += $now - $limit_lastlogin{$u};
	}

return (\%rv, \%limit_rv);
}

# get_past_days_usage(user)
# Returns a list of array refs, each with day, playtime and enforced playtime
sub get_past_day_usage
{
my ($u) = @_;
my $ufile = "$playtime_dir/$u";
my %days;
&read_file($ufile, \%days);
my @rv;
foreach my $k (sort { $a cmp $b } (keys %days)) {
	next if ($k !~ /^total_(\d+\-\d+\-\d+)$/);
	my $day = $1;
	push(@rv, [ $day, $days{"total_".$day}, $days{"limit_".$day} ]);
	}
return @rv;
}

# list_playtime_users()
# Returns a list of all users for which we have playtime stats
sub list_playtime_users
{
opendir(DIR, $playtime_dir) || return ();
my @users = grep { !/^\./ } readdir(DIR);
closedir(DIR);
return @users;
}

# nice_seconds(secs)
# Converts a number of seconds into HH:MM format
sub nice_seconds
{
my ($time) = @_;
my $days = int($time / (24*60*60));
my $hours = int($time / (60*60)) % 24;
my $mins = sprintf("%d", int($time / 60) % 60);
my $secs = sprintf("%d", int($time) % 60);
if ($days) {
	return "$days days, $hours hours, $mins mins";
	}
elsif ($hours) {
	return "$hours hours, $mins mins";
	}
else {
	return "$mins mins";
	}
}

# limit_user(ip, user, date)
# Returns 1 if some usage should be counted for limiting purposes
sub limit_user
{
my ($ip, $user, $date) = @_;
my @users = split(/\s+/, $config{'playtime_users'});
if (@users && &indexoflc($user, @users) < 0) {
	return 0;
	}
my @ips = split(/\s+/, $config{'playtime_ips'});
if (@ips && !&webmin::ip_match($ip, @ips)) {
	return 0;
	}
my @days = split(/\s+/, $config{'playtime_days'});
if (@days > 0 && @days < 7) {
	my ($y, $m, $d) = split(/\-/, $date);
	my @tm = localtime(timelocal(0, 0, 0, $d, $m-1, $y-1900));
	if (@tm && &indexof($tm[6], @days) < 0) {
		return 0;
		}
	}
return 1;
}

# check_playtime_limits()
# Function called by webmincron to update and enforce playtime usage
sub check_playtime_limits
{
# Get usage for today, and update today's files
my ($usage, $limit_usage) = &get_current_day_usage();
if (!-d $playtime_dir) {
	&make_dir($playtime_dir, 0700);
	}
my $today = strftime("%Y-%m-%d", localtime(time()));
my (@bans, @unbans);
foreach my $u (keys %$usage) {
	my $ufile = "$playtime_dir/$u";
	my %days;
	&read_file($ufile, \%days);
	$days{"total_".$today} = $usage->{$u};
	$days{"limit_".$today} = $limit_usage->{$u};
	if ($config{'playtime_max'} &&
            $limit_usage->{$u} > $config{'playtime_max'}*60) {
		# Flag as banned
		if (!$days{"banned_".$today}) {
			$days{"banned_".$today} = 1;
			push(@bans, $u);
			}
		}
	else {
		# Not banned
		if ($days{"banned_".$today}) {
			push(@unbans, $u);
			}
		}
	&write_file($ufile, \%days);
	}

# Band and un-ban players
my @banned = &list_banned_players();
foreach my $u (@bans) {
	&execute_minecraft_command(
	    "/ban $u Exceeded $config{'playtime_max'} minutes of play time");
	}
foreach my $u (@unbans) {
	&execute_minecraft_command("/pardon $u");
	}
}

# get_playtime_job()
# Returns the webmincron job to enforce play time limits
sub get_playtime_job
{
&foreign_require("webmincron");
my @jobs = &webmincron::list_webmin_crons();
my ($job) = grep { $_->{'module'} eq $module_name &&
		   $_->{'func'} eq "check_playtime_limits" } @jobs;
return $job;
}

# get_player_stats(name, [world])
# Returns all stats available for a player, in the format of the JSON file
sub get_player_stats
{
my ($name, $world) = @_;
if (!$world) {
	my $conf = &get_minecraft_config();
	$world = &find_value("level-name", $conf);
	$world ||= "world";
	}
my $uuid = &uuid_to_username($name);
my $wdir = "$config{'minecraft_dir'}/$world";
my $file = "$wdir/stats/$name.json";
if (!-r $file) {
	$file = "$wdir/stats/$uuid.json";
	}
if (!-r $file) {
	return $text{'conn_nostats'};
	}
eval "use JSON::PP";
return &text('conn_noperl', "<tt>JSON::PP</tt>") if ($@);
my $coder = JSON::PP->new->pretty;
my $perl;
eval {
	$perl = $coder->decode(&read_file_contents($file));
	};
return &text('conn_ejson', $@) if ($@);
return $perl;
}

# minecraft_server_type()
# Returns 'default' or 'bukkit'
sub minecraft_server_type
{
my $jar = &get_minecraft_jar();
return $jar =~ /bukkit-[0-9]/ ? 'bukkit' : 'default';
}

# list_installed_versions()
# Returns a list of hash refs, one per available server version
sub list_installed_versions
{
# Find all the jars
my @files;
my $dir = $config{'minecraft_dir'};
my $cur = &get_minecraft_jar();
opendir(DIR, $dir);
foreach my $f (readdir(DIR)) {
	push(@files, $dir."/".$f) if ($f =~ /\.jar$/);
	}
closedir(DIR);
push(@files, $cur) if (&indexof($cur, @files) < 0);

# Figure out what they are
my @rv;
foreach my $f (sort { $a cmp $b } @files) {
	my $ver = { 'path' => $f };
	$ver->{'file'} = $f =~ /^\Q$dir\E\/(.*)/ ? $1 : $f;
	$ver->{'ver'} = $f =~ /([0-9][0-9\.]+)\.jar$/ ? $1 : "Unknown";
	$ver->{'desc'} = $ver->{'ver'};
	push(@rv, $ver);
	}
return @rv;
}

# save_minecraft_jar(file)
# Update the server jar file
sub save_minecraft_jar
{
my ($file) = @_;
my $dir = $config{'minecraft_dir'};
&lock_file($module_config_file);
if ($file =~ /^\Q$dir\E\/(.*)$/) {
	$config{'minecraft_jar'} = $1;
	}
else {
	$config{'minecraft_jar'} = $file;
	}
&save_module_config(\%config);
&unlock_file($module_config_file);
}

1;
