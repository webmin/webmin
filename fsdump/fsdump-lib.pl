#!/usr/local/bin/perl
# fsdump-lib.pl
# Common functions for doing filesystem backups with dump

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
if ($gconfig{'os_type'} =~ /^\S+\-linux$/) {
	do "linux-lib.pl";
	}
else {
	do "$gconfig{'os_type'}-lib.pl";
	}
&foreign_require("mount", "mount-lib.pl");
%access = &get_module_acl();

$cron_cmd = "$module_config_directory/backup.pl";
$newtape_cmd = "$module_config_directory/newtape.pl";
$notape_cmd = "$module_config_directory/notape.pl";
$multi_cmd = "$module_config_directory/multi.pl";
$rmulti_cmd = "$module_config_directory/rmulti.pl";
$ftp_cmd = "$module_config_directory/ftp.pl";

# list_dumps()
# Returns a list of all scheduled dumps
sub list_dumps
{
local (@rv, $f);
opendir(DIR, $module_config_directory);
foreach $f (sort { $a cmp $b } readdir(DIR)) {
	next if ($f !~ /^(\S+)\.dump$/);
	push(@rv, &get_dump($1));
	}
closedir(DIR);
return @rv;
}

# get_dump(id)
sub get_dump
{
local %dump;
&read_file("$module_config_directory/$_[0].dump", \%dump) || return undef;
$dump{'id'} = $_[0];
return \%dump;
}

# save_dump(&dump)
sub save_dump
{
$_[0]->{'id'} = $$.time() if (!$_[0]->{'id'});
&lock_file("$module_config_directory/$_[0]->{'id'}.dump");
&write_file("$module_config_directory/$_[0]->{'id'}.dump", $_[0]);
&unlock_file("$module_config_directory/$_[0]->{'id'}.dump");
}

# delete_dump(&dump)
sub delete_dump
{
&lock_file("$module_config_directory/$_[0]->{'id'}.dump");
unlink("$module_config_directory/$_[0]->{'id'}.dump");
&unlock_file("$module_config_directory/$_[0]->{'id'}.dump");
}

# directory_filesystem(dir)
# Returns the filesystem type of some directory , or the full details
# if requesting an array
sub directory_filesystem
{
local $fs;
foreach my $m (sort { length($a->[0]) <=> length($b->[0]) }
	         &mount::list_mounted()) {
	local $l = length($m->[0]);
	if ($m->[0] eq $_[0] || $m->[0] eq "/" ||
	    (length($_[0]) >= $l && substr($_[0], 0, $l+1) eq $m->[0]."/")) {
		$fs = $m;
		}
	}
return wantarray ? @$fs : $fs->[2];
}

# is_mount_point(dir)
# Returns 1 if some directory is a filesystem mount point
sub is_mount_point
{
local ($dir) = @_;
foreach my $m (&mount::list_mounted()) {
	return 1 if ($m->[0] eq $dir);
	}
return 0;
}

# same_filesystem(fs1, fs2)
# Returns 1 if type filesystem types are the same
sub same_filesystem
{
local ($fs1, $fs2) = @_;
$fs1 = "ext2" if ($fs1 eq "ext3");
$fs2 = "ext2" if ($fs2 eq "ext3");
return lc($fs1) eq lc($fs2);
}

# date_subs(string, [time])
sub date_subs
{
local ($path, $time) = @_;
local $rv;
if ($config{'date_subs'}) {
	eval "use POSIX";
	eval "use posix" if ($@);
	local @tm = localtime($time || time());
	&clear_time_locale();
	$rv = strftime($path, @tm);
	&reset_time_locale();
	}
else {
	$rv = $path;
	}
if ($config{'webmin_subs'}) {
	$rv = &substitute_template($rv, { });
	}
return $rv;
}

# execute_before(&dump, handle, escape)
# Executes the before-dump command, and prints the output. Returns 1 on success
# or 0 on failure
sub execute_before
{
if ($_[0]->{'before'}) {
	local $h = $_[1];
	&open_execute_command(before, "($_[0]->{'before'}) 2>&1 </dev/null", 1);
	while(<before>) {
		print $h $_[2] ? &html_escape($_) : $_;
		}
	close(before);
	return !$?;
	}
return 1;
}

# execute_after(&dump, handle, escape)
sub execute_after
{
if ($_[0]->{'after'}) {
	local $h = $_[1];
	&open_execute_command(after, "($_[0]->{'after'}) 2>&1 </dev/null", 1);
	while(<after>) {
		print $h $_[2] ? &html_escape($_) : $_;
		}
	close(after);
	return !$?;
	}
return 1;
}

# running_dumps(&procs)
# Returns a list of backup jobs currently in progress, and their statuses
sub running_dumps
{
local ($p, @rv, %got);
foreach $p (@{$_[0]}) {
	if (($p->{'args'} =~ /$cron_cmd\s+(\S+)/ ||
	    $p->{'args'} =~ /$module_root_directory\/backup.pl\s+(\S+)/) &&
	    $p->{'args'} !~ /^\/bin\/(sh|bash|csh|tcsh)/) {
		local $backup = &get_dump($1);
		local $sfile = "$module_config_directory/$1.$p->{'pid'}.status";
		local %status;
		if (&read_file($sfile, \%status)) {
			$backup->{'status'} = \%status;
			$backup->{'pid'} = $p->{'pid'};
			push(@rv, $backup);
			$got{$sfile} = 1 if (!$status{'end'});
			}
		}
	}
# Remove any left over .status files
opendir(DIR, $module_config_directory);
local $f;
foreach $f (readdir(DIR)) {
	local $path = "$module_config_directory/$f";
	unlink($path) if ($path =~ /\.status$/ && !$got{$path});
	}
closedir(DIR);
return @rv;
}

# can_edit_dir(dir)
# Returns 1 if some backup can be used or edited
sub can_edit_dir
{
return 1 if ($access{'dirs'} eq '*');
local ($d, $dd);
local @ddirs = !ref($_[0]) ? ( $_[0] ) :
	       $supports_multiple ? split(/\s+/, $_[0]->{'dir'}) :
				    ( $_[0]->{'dir'} );
foreach $dd (@ddirs) {
	local $anyok = 0;
	foreach $d (split(/\t+/, $access{'dirs'})) {
		$anyok = 1 if (&is_under_directory($d, $dd));
		}
	return 0 if (!$anyok);
	}
return 1;
}

sub create_wrappers
{
&foreign_require("cron", "cron-lib.pl");
&cron::create_wrapper($notape_cmd, $module_name, "notape.pl");
&cron::create_wrapper($newtape_cmd, $module_name, "newtape.pl");
&cron::create_wrapper($multi_cmd, $module_name, "multi.pl");
&cron::create_wrapper($rmulti_cmd, $module_name, "rmulti.pl");
}

# new_header(title)
sub new_header
{
print "</table></td></tr></table><br>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$_[0]</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
}

# dump_directories(&dump)
sub dump_directories
{
if (!&multiple_directory_support($_[0]->{'fs'})) {
	return $_[0]->{'dir'};
	}
elsif ($_[0]->{'tabs'}) {
	return split(/\t+/, $_[0]->{'dir'});
	}
else {
	return split(/\s+/, $_[0]->{'dir'});
	}
}

# run_ssh_command(command, output-fh, output-mode, password)
# Run some command and display it's output, possibly providing a password
# if one is requested
sub run_ssh_command
{
local ($cmd, $fh, $fhmode, $pass) = @_;
&foreign_require("proc", "proc-lib.pl");
local ($cfh, $fpid) = &proc::pty_process_exec_logged($cmd);
local ($wrong_password, $got_login, $connect_failed);
local $out;
local $stars = ("*" x length($pass));
while(1) {
	local $rv = &wait_for($cfh, "password:", "yes\\/no", "(^|\\n)\\s*Permission denied.*\n", "ssh: connect.*\n", ".*\n");
	if ($wait_for_input !~ /^\s*DUMP:\s+ACLs\s+in\s+inode/i) {
		$wait_for_input =~ s/\Q$pass\E/$stars/g;
		if ($fhmode) {
			print $fh &html_escape($wait_for_input);
			}
		else {
			print $fh $wait_for_input;
			}
		}
	if ($rv == 0) {
		syswrite($cfh, "$pass\n");
		}
	elsif ($rv == 1) {
		syswrite($cfh, "yes\n");
		}
	elsif ($rv == 2) {
		$wrong_password++;
		last;
		}
	elsif ($rv == 3) {
		$connect_failed++;
		}
	elsif ($rv < 0) {
		last;
		}
	}
close($cfh);
local $got = waitpid($fpid, 0);
return $?;
}

# rsh_command_input(selname, textname, value)
# Returns HTML for selecting an rsh command
sub rsh_command_input
{
local ($selname, $textname, $rsh) = @_;
local $ssh = &has_command("ssh");
local $r = $ssh && $rsh eq $ssh ? 1 :
	   $rsh eq $ftp_cmd ? 3 :
	   $rsh ? 2 : 0;
local @opts = ( [ 0, $text{'dump_rsh0'} ],
		[ 1, $text{'dump_rsh1'} ],
		[ 3, $text{'dump_rsh3'} ] );
if ($r == 2) {
	push(@opts, [ 2, $text{'dump_rsh2'}." ".
			 &ui_textbox($textname, $rsh, 30) ]);
	}
return &ui_radio($selname, $r, \@opts);
}

# rsh_command_parse(selname, textname)
# Returns the rsh command to use for a backup/restore, based on %in
sub rsh_command_parse
{
local ($selname, $textname) = @_;
if ($in{$selname} == 0) {
	return undef;
	}
elsif ($in{$selname} == 1) {
	local $ssh = &has_command("ssh");
	$ssh || &error($text{'dump_essh'});
	return $ssh;
	}
elsif ($in{$selname} == 3) {
	return $ftp_cmd;
	}
else {
	$in{$textname} =~ /^(\S+)/ && &has_command("$1") ||
		&error($text{'dump_ersh'});
	return $in{$textname};
	}
}

1;

