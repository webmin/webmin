# webalizer-lib.pl
# Common functions for editing the webalizer config file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

$cron_cmd = "$module_config_directory/webalizer.pl";
$custom_logs_file = "$module_config_directory/custom-logs";
%access = &get_module_acl();

# Use sample config if needed
if (!-r $config{'webalizer_conf'} && -r $config{'alt_conf'}) {
	&copy_source_dest($config{'alt_conf'}, $config{'webalizer_conf'});
	}

# get_config([logfile])
# Parse the webalizer config file for a single logfile or global
sub get_config
{
local $file;
if ($_[0]) {
	$file = &config_file_name($_[0]);
	}
$file = $config{'webalizer_conf'} if (!$file || !-r $file);
local @rv;
local $lnum = 0;
open(FILE, $file);
while(<FILE>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^\s*(\S+)\s+(.*)/) {
		push(@rv, { 'name' => $1,
			    'value' => $2,
			    'line' => $lnum,
			    'file' => $file,
			    'index' => scalar(@rv) });
		}
	$lnum++;
	}
close(FILE);
return \@rv;
}

# save_directive(&config, name, [value]*)
sub save_directive
{
local ($conf, $name, @values) = @_;
local @old = &find($name, $conf);
local $lref = &read_file_lines($conf->[0]->{'file'});
local $i;
for($i=0; $i<@old || $i<@values; $i++) {
	if ($i < @old && $i < @values) {
		# Just replacing a line
		$lref->[$old[$i]->{'line'}] = "$name $values[$i]";
		}
	elsif ($i < @old) {
		# Deleting a line
		splice(@$lref, $old[$i]->{'line'}, 1);
		&renumber($conf, $old[$i]->{'line'}, -1);
		}
	elsif ($i < @values) {
		# Adding a line
		if (@old) {
			# after the last one of the same type
			splice(@$lref, $old[$#old]->{'line'}+1, 0,
			       "$name $values[$i]");
			&renumber($conf, $old[$#old]->{'line'}+1, 1);
			}
		else {
			# at end of file
			push(@$lref, "$name $values[$i]");
			}
		}
	}
}

# renumber(&config, line, offset)
sub renumber
{
foreach $c (@{$_[0]}) {
	$c->{'line'} += $_[2] if ($c->{'line'} >= $_[1]);
	}
}

# config_file_name(logfile)
sub config_file_name
{
local $p = $_[0];
$p =~ s/^\///;
$p =~ s/\//_/g;
return "$module_config_directory/$p.conf";
}

# find(name, &config)
sub find
{
local @rv;
foreach $c (@{$_[1]}) {
	push(@rv, $c) if (lc($c->{'name'}) eq lc($_[0]));
	}
return wantarray ? @rv : $rv[0];
}

# find_value(name, &config)
sub find_value
{
local @rv = map { $_->{'value'} } &find(@_);
return wantarray ? @rv : $rv[0];
}

# all_log_files(file)
# Given a base log file name, returns a list of all log files in the same
# directory that start with the same name
sub all_log_files
{
$_[0] =~ /^(.*)\/([^\/]+)$/;
local $dir = $1;
local $base = $2;
local ($f, @rv);
opendir(DIR, $dir);
foreach $f (readdir(DIR)) {
	if ($f =~ /^\Q$base\E/ && -f "$dir/$f") {
		push(@rv, "$dir/$f");
		}
	}
closedir(DIR);
return @rv;
}

# get_log_config(path)
# Get the configuration for some log file
sub get_log_config
{
local %rv;
&read_file(&log_config_name($_[0]), \%rv) || return undef;
return \%rv;
}

# save_log_config(path, &config)
sub save_log_config
{
return &write_file(&log_config_name($_[0]), $_[1]);
}

# log_config_name(path)
sub log_config_name
{
local $p = $_[0];
$p =~ s/^\///;
$p =~ s/\//_/g;
return "$module_config_directory/$p.log";
}

# generate_report(file, handle, escape)
# Generates a new webalizer report to the configured directory, and sends
# any output to the given file handle. Returns 1 if any of the log files
# worked OK.
sub generate_report
{
local $h = $_[1];
local $lconf = &get_log_config($_[0]);
local @all = $config{'skip_old'} ? ( $_[0] ) : &all_log_files($_[0]);
if (!@all) {
	print $h "Log file $_[0] does not exist\n";
	return;
	}
local ($a, %mtime);
foreach $a (@all) {
	local @st = stat($a);
	$mtime{$a} = $st[9];
	}
local $prog = &get_webalizer_prog();
local $type = $lconf->{'type'} == 1 ? "" :
	      $lconf->{'type'} == 2 ? "-F squid" :
	      $lconf->{'type'} == 3 ? "-F ftp" : "";
local $cfile = &config_file_name($_[0]);
local $conf = -r $cfile ? "-c $cfile" : "";
if ($lconf->{'over'} && !&is_readonly_mode()) {
	unlink("$lconf->{'dir'}/webalizer.current");
	unlink("$lconf->{'dir'}/webalizer.hist");
	}
unlink("$lconfig->{'dir'}/__db.dns_cache.db");
local $user = $lconf->{'user'} || "root";
if ($user ne "root" && -r $cfile) {
	chmod(0644, $cfile);
	}
if (!-d $lconf->{'dir'}) {
	mkdir($lconf->{'dir'}, 0755);
	if ($user ne "root") {
		local @uinfo = getpwnam($user);
		chown($uinfo[2], $uinfo[3], $lconf->{'dir'});
		}
	}
local $anyok = 0;
foreach $a (sort { $mtime{$a} <=> $mtime{$b} } @all) {
	local $cmd = "$config{'webalizer'} $conf -o ".
		     quotemeta($lconf->{'dir'})." $type -p ".quotemeta($a);
	if ($user ne "root") {
		$cmd = &command_as_user($user, 0, $cmd);
		}
	&open_execute_command(OUT, "$cmd 2>&1", 1);
	while(<OUT>) {
		print $h $_[2] ? &html_escape($_) : $_;
		}
	close(OUT);
	$anyok = 1 if (!$?);
	&additional_log("exec", undef, $cmd);
	}
return $anyok;
}

# spaced_buttons(button, ...)
sub spaced_buttons
{
local $pc = int(100 / scalar(@_));
print "<table width=100%><tr>\n";
foreach $b (@_) {
	local $al = $b eq $_[0] ? "align=left" :
		    $b eq $_[@_-1] ? "align=right" : "align=center";
	print "<td width=$pc% $al>$b</td>\n";
	}
print "</table>\n";
}

# read_custom_logs()
sub read_custom_logs
{
open(LOGS, $custom_logs_file);
local @rv = map { /^(.*\S)\s+(\S+)/; { 'file' => $1, 'type' => $2 } } <LOGS>;
close(LOGS);
return @rv;
}

# write_custom_logs(log, ...)
sub write_custom_logs
{
&open_tempfile(LOGS, ">$custom_logs_file");
&print_tempfile(LOGS, map { "$_->{'file'} $_->{'type'}\n" } @_);
&close_tempfile(LOGS);
}

# can_edit_log(file)
sub can_edit_log
{
foreach $d (split(/\s+/, $access{'dir'})) {
	local $ok = &is_under_directory($d, $_[0]);
	return 1 if ($ok);
	}
return 0;
}

# get_webalizer_version(&out)
# Returns the Webalizer version number, and puts output into the given scalar
# reference.
sub get_webalizer_version
{
local $out = &backquote_command("$config{'webalizer'} -V 2>&1 </dev/null");
${$_[0]} = $out;
return $out =~ /\sV(\S+)/ ? $1 : undef;
}

# get_webalizer_prog()
# Returns either 'webalizer' or 'awffull'
sub get_webalizer_prog
{
return $config{'webalizer'} =~ /awffull/i ? "awffull" : "webalizer";
}

# get_all_logs()
# Returns a list of all log files the module can report on
sub get_all_logs
{
# Query apache and squid for their logfiles
local %auto = map { $_, 1 } split(/,/, $config{'auto'});
local @logs;
if (&foreign_installed("apache") && $auto{'apache'}) {
	&foreign_require("apache", "apache-lib.pl");
	local $conf = &apache::get_config();
	local @dirs = ( &apache::find_all_directives($conf, "CustomLog"),
		  	&apache::find_all_directives($conf, "TransferLog") );
	local $root = &apache::find_directive_struct("ServerRoot", $conf);
	local $d;
	foreach $d (@dirs) {
		local $lf = $d->{'words'}->[0];
		if ($lf =~ /^\|\S+writelogs.pl\s+\S+\s+(\S+)/) {
			# Virtualmin log writer .. use real file
			$lf = $1;
			}
		next if ($lf =~ /^\|/);
		if ($lf !~ /^\//) {
			$lf = "$root->{'words'}->[0]/$lf";
			}
		open(FILE, $lf);
		local $line = <FILE>;
		close(FILE);
		if (!$line || $line =~ /^([a-zA-Z0-9\.\-\:]+)\s+\S+\s+\S+\s+\[\d+\/[a-zA-z]+\/\d+:\d+:\d+:\d+\s+[0-9\+\-]+\]/) {
			push(@logs, { 'file' => $lf,
				      'type' => 1 });
			}
		}
	}

# Add log file from Squid
if (&foreign_installed("squid") && $auto{'squid'}) {
	&foreign_require("squid", "squid-lib.pl");
	local $conf = &squid::get_config();
	local $log = &squid::find_value("cache_access_log", $conf);
	$log = "$squid::config{'log_dir'}/access.log"
		if (!$log && -d $squid::config{'log_dir'});
	push(@logs, { 'file' => $log,
		      'type' => 2 }) if ($log);
	}

# Add log file from proftpd
if (&foreign_installed("proftpd") && $auto{'proftpd'}) {
	&foreign_require("proftpd", "proftpd-lib.pl");
	local $conf = &proftpd::get_config();
	local $global = &proftpd::find_directive_struct("Global", $conf);
	local $log = &proftpd::find_directive("TransferLog", $global->{'members'}) || "/var/log/xferlog";
	push(@logs, { 'file' => $log, 'type' => 3 });
	}

# Add log file from wu-ftpd
if (&foreign_installed("wuftpd") && $auto{'wuftpd'}) {
	local %wconfig = &foreign_config("wuftpd");
	push(@logs, { 'file' => $wconfig{'log_file'}, 'type' => 3 });
	}

# Add custom logfiles
push(@logs, map { $_->{'custom'} = 1; $_ } &read_custom_logs());

return @logs;
}

# lconf_to_cron(&lconf, &job)
# Copy fields from a webalizer config to a cron job
sub lconf_to_cron
{
local ($lconf, $job) = @_;
$job->{'special'} = $lconf->{'special'};
$job->{'mins'} = $lconf->{'mins'};
$job->{'hours'} = $lconf->{'hours'};
$job->{'days'} = $lconf->{'days'};
$job->{'months'} = $lconf->{'months'};
$job->{'weekdays'} = $lconf->{'weekdays'};
}

1;

