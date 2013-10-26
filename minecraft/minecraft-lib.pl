# Functions for editing the minecraft config

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
use WebminCore;
use Time::Local;
use POSIX;
&init_config();
our ($module_root_directory, %text, %gconfig, $root_directory, %config,
     $module_name, $remote_user, $base_remote_user, $gpgpath,
     $module_config_directory, @lang_order_list, @root_directories);
our $history_file = "$module_config_directory/history.txt";
our $download_page_url = "http://minecraft.net/download";
our $playtime_dir = "$module_config_directory/playtime";

&foreign_require("webmin");

# check_minecraft_server()
# Returns an error message if the Minecraft server is not installed
sub check_minecraft_server
{
-d $config{'minecraft_dir'} ||
	return &text('check_edir', $config{'minecraft_dir'});
my $jar = $config{'minecraft_jar'} ||
	  $config{'minecraft_dir'}."/"."minecraft_server.jar";
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
my ($pid) = &proc::find_socket_processes("tcp:25565");
return $pid if ($pid);
my @procs = &proc::list_processes();
foreach my $p (@procs) {
	if ($p->{'args'} =~ /^java.*minecraft_server.jar/) {
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
my $jar = $config{'minecraft_jar'} ||
	  $config{'minecraft_dir'}."/"."minecraft_server.jar";
my $shortjar = $jar;
$shortjar =~ s/^.*\///;
foreach my $p (@procs) {
	if ($p->{'args'} =~ /^\S*\Q$config{'java_cmd'}\E.*(\Q$jar\E|\Q$shortjar\E)/) {
		return $p->{'pid'};
		}
	}
return undef;
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
my $jar = $config{'minecraft_jar'} ||
	  $config{'minecraft_dir'}."/"."minecraft_server.jar";
my $ififo = &get_input_fifo();
my $rv = "(test -e ".$ififo." || mkfifo ".$ififo.") ; ".
	 "cd ".$config{'minecraft_dir'}." && ".
	 "(tail -f ".$ififo." | ".
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

# stop_minecraft_server()
# Kill the server, if running
sub stop_minecraft_server
{
my $pid = &is_minecraft_server_running();
$pid || return "Not running!";

# Try graceful shutdown
&send_server_command("/save-all");
&send_server_command("/stop");
for(my $i=0; $i<10; $i++) {
	last if (!&is_minecraft_server_running());
	sleep(1);
	}

# Clean kill
if (&is_minecraft_server_running()) {
	kill('TERM', $pid);
	for(my $i=0; $i<10; $i++) {
		last if (!&is_minecraft_server_running());
		sleep(1);
		}
	}

# Fatal kill
if (&is_minecraft_server_running()) {
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
	if ($l !~ /players\s+online:/ && $l =~ /\[INFO\]\s+(\S.*)$/) {
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
my $fh = "TAIL";
my @events;
&open_execute_command($fh, "tail -10000 $logfile", 1, 1);
while(<$fh>) {
	if (/^(\d+)\-(\d+)\-(\d+)\s+(\d+):(\d+):(\d+)\s+\[\S+\]\s+(.*)/) {
		my ($y, $mo, $d, $h, $m, $s, $msg) =($1, $2, $3, $4, $5, $6, $7);
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
	}
close($fh);
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
return "<input type=button onClick='ifield = document.forms[0].$field; chooser = window.open(\"item_chooser.cgi?item=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=400,height=600\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

# list_minecraft_items()
# Returns a list of hash refs with id and name keys
# CSV generated with :
# wget -O - http://minecraft-ids.grahamedgecombe.com/ | grep /items/ | perl -ne 's/.*items.([0-9:]+)">([^<]+)<.*/$1,$2/; print ' > items.csv
sub list_minecraft_items
{
my $fh = "ITEMS";
&open_readfile($fh, "$module_root_directory/items.csv");
my @rv;
while(<$fh>) {
	s/\r|\n//g;
	my ($id, $name) = split(/,/, $_);
	push(@rv, { 'id' => $id,
		    'name' => $name });
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
	if ($l !~ /banned\s+players:/ && $l =~ /\[INFO\]\s+(\S.*)$/) {
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
	if ($l !~ /whitelisted\s+players:/ && $l =~ /\[INFO\]\s+(\S.*)$/) {
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
	my @players = map { s/^.*\///; s/\.dat$//; $_ }
			  glob("$path/players/*");
	push(@rv, { 'path' => $path,
		    'name' => $name,
		    'size' => &disk_usage_kb($path)*1024,
		    'lock' => (-r "$path/session.lock"),
		    'players' => \@players });
	}
return @rv;
}

# list_banned_ips()
# Returns an array of banned addresses
sub list_banned_ips
{
my @out = &execute_minecraft_command("/banlist ips", 1);
my @rv;
foreach my $l (@out) {
	if ($l !~ /banned\s+IP\s+addresses:/ && $l =~ /\[INFO\]\s+(\S.*)$/) {
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
# Returns the URL for downloading the server JAR file
sub get_server_jar_url
{
my ($host, $port, $page, $ssl) = &parse_http_url($download_page_url);
return undef if (!$host);
my ($out, $err);
&http_download($host, $port, $page, \$out, \$err, undef, $ssl);
return undef if ($err);
$out =~ /"((http|https):[^"]+minecraft_server[^"]+\.jar)"/ || return undef;
return $1;
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
	&send_backup_email("No worlds were found to backup!", 1);
	return;
	}

# Get destination dir, with strftime
my @tm = localtime(time());
&clear_time_locale();
my $dir = strftime($config{'backup_dir'}, @tm);
&reset_time_locale();

# Create destination dir
if (!-d $dir) {
	if (!&make_dir($dir, 0755)) {
		&send_backup_email(
			"Failed to create destination directory $dir : $!");
		return;
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
&send_backup_email(join("\n", @out)."\n", $failed);
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

# update_last_check()
# If the last check time is too old, check for the latest version
sub update_last_check
{
if (time() - $config{'last_check'} > 6*60*60) {
	my $sz = &check_server_download_size();
	$config{'last_check'} = time();
	$config{'last_size'} = $sz;
	&save_module_config();
	}
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
while(1) {
	$pos -= 4096;
	$pos = 0 if ($pos < 0);
	seek(LOGFILE, $pos, 0);
	last if ($pos == 0);
	my $dummy = <LOGFILE>;	# Skip partial line
	my $line = <LOGFILE>;
	$line =~ /^((\d+)\-(\d+)\-(\d+))/ || next;
	if ($1 ne $wantday) {
		# Found a line for another day
		last;
		}
	}

# Read forwards, looking for logins and logouts for today
my (%rv, %limit_rv);
my (%lastlogin, %limit_lastlogin);
while(my $line = <LOGFILE>) {
	$line =~ /^((\d+)\-(\d+)\-(\d+))\s+(\d+):(\d+):(\d+)/ || next;
	my $day = $1;
	$day eq $wantday || next;
	my $secs = $5*60*60 + $6*60 + $7;
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



1;
