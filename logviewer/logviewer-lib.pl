# logviewer-lib.pl
# Functions for the syslog module

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();

# can_edit_log(&log|file)
# Returns 1 if some log can be viewed/edited, 0 if not
sub can_edit_log
{
return 1 if (!$access{'logs'});
local @files = split(/\s+/, $access{'logs'});
local $lf;
if (ref($_[0])) {
	$lf = $_[0]->{'file'} || $_[0]->{'pipe'} || $_[0]->{'host'} ||
	      $_[0]->{'socket'} || $_[0]->{'cmd'} ||
	      ($_[0]->{'all'} ? "*" : "users");
	}
else {
	$lf = $_[0];
	}
foreach $f (@files) {
	return 1 if ($f eq $lf || &is_under_directory($f, $lf));
	}
return 0;
}

# 
# Returns standard 
sub get_systemctl_cmds
{
my $lines = $config{'lines'} || 1000;
return !&has_command('journalctl') ? () : (
	{ 'cmd' => "journalctl --lines $lines -p alert..emerg",
	  'desc' => $text{'journal_journalctl_alert_emerg'},
	  'id' => "journal-1", },
	{ 'cmd' => "journalctl --lines $lines -p err..crit",
	  'desc' => $text{'journal_journalctl_err_crit'},
	  'id' => "journal-2", },
	{ 'cmd' => "journalctl --lines $lines -p notice..warning",
	  'desc' => $text{'journal_journalctl_notice_warning'},
	  'id' => "journal-3", },
	{ 'cmd' => "journalctl --lines $lines -p debug..info",
	  'desc' => $text{'journal_journalctl_debug_info'},
	  'id' => "journal-4", },
	{ 'cmd' => "journalctl --lines $lines -k ",
	  'desc' => $text{'journal_journalctl_dmesg'},
	  'id' => "journal-5", },
	{ 'cmd' => "journalctl --lines $lines -x ",
	  'desc' => $text{'journal_expla_journalctl'},
	  'id' => "journal-6", }, 
	{ 'cmd' => "journalctl --lines $lines",
	  'desc' => $text{'journal_journalctl'},
	  'id' => "journal-7", } );
}

# all_log_files(file)
# Given a filename, returns all rotated versions, ordered by oldest first
sub all_log_files
{
$_[0] =~ /^(.*)\/([^\/]+)$/;
local $dir = $1;
local $base = $2;
local ($f, @rv);
opendir(DIR, &translate_filename($dir));
foreach $f (readdir(DIR)) {
	local $trans = &translate_filename("$dir/$f");
	if ($f =~ /^\Q$base\E/ && -f $trans && $f !~ /\.offset$/) {
		push(@rv, "$dir/$f");
		$mtime{"$dir/$f"} = [ stat($trans) ];
		}
	}
closedir(DIR);
return sort { $mtime{$a}->[9] <=> $mtime{$b}->[9] } @rv;
}

# get_other_module_logs([module])
# Returns a list of logs supplied by other modules
sub get_other_module_logs
{
local ($mod) = @_;
local @rv;
local %done;
foreach my $minfo (&get_all_module_infos()) {
	next if ($mod && $minfo->{'dir'} ne $mod);
	next if (!$minfo->{'syslog'});
	next if ($minfo->{'dir'} =~ /^(init|proc)$/);
	next if (!&foreign_installed($minfo->{'dir'}));
	local $mdir = &module_root_directory($minfo->{'dir'});
	next if (!-r "$mdir/syslog_logs.pl");
	&foreign_require($minfo->{'dir'}, "syslog_logs.pl");
	local $j = 0;
	foreach my $l (&foreign_call($minfo->{'dir'}, "syslog_getlogs")) {
		local $fc = $l->{'file'} || $l->{'cmd'};
		next if ($done{$fc}++);
		$l->{'minfo'} = $minfo;
		$l->{'mod'} = $minfo->{'dir'};
		$l->{'mindex'} = $j++;
		push(@rv, $l);
		}
	}
@rv = sort { $a->{'minfo'}->{'desc'} cmp $b->{'minfo'}->{'desc'} } @rv;
local $i = 0;
foreach my $l (@rv) {
	$l->{'index'} = $i++;
	}
return @rv;
}

# extra_log_files()
# Returns a list of extra log files available to the current Webmin user. No filtering
# based on allowed directory is done though!
sub extra_log_files
{
local @rv;
foreach my $fd (split(/\t+/, $config{'extras'}), split(/\t+/, $access{'extras'})) {
	if ($fd =~ /^"(\S+)"\s+"(\S.*)"$/) {
		push(@rv, { 'file' => $1, 'desc' => $2 });
		}
	elsif ($fd =~ /^"(\S+)"$/) {
		push(@rv, { 'file' => $1 });
		}
	elsif ($fd =~ /^(\S+)\s+(\S.*)$/) {
		push(@rv, { 'file' => $1, 'desc' => $2 });
		}
	else {
		push(@rv, { 'file' => $fd });
		}
	}
return @rv;
}

1;

