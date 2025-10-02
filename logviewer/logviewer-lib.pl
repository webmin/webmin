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

# get_journal_since
# Returns a list of journalctl since commands
sub get_journal_since
{
return [
        { "" => $text{'journal_since0'} },
        { "--follow" => $text{'journal_since1'} },
        { "--boot" => $text{'journal_since2'} },
        { "--boot -1" => $text{'journal_since2-1'} },
        { "--since '30 days ago'" => $text{'journal_since30'} },
        { "--since '7 days ago'" => $text{'journal_since3'} },
        { "--since '24 hours ago'" => $text{'journal_since4'} },
        { "--since '8 hours ago'" => $text{'journal_since5'} },
        { "--since '1 hour ago'" => $text{'journal_since6'} },
        { "--since '30 minutes ago'" => $text{'journal_since7'} },
        { "--since '10 minutes ago'" => $text{'journal_since8'} },
        { "--since '3 minutes ago'" => $text{'journal_since9'} },
        { "--since '1 minute ago'" => $text{'journal_since10'} },
    ];
}

# get_systemctl_cmds([force-select])
# Returns logs for journalctl
sub get_systemctl_cmds
{
my $fselect = shift;
my $lines = $in{'lines'} ? int($in{'lines'}) : int($config{'lines'}) || 1000;
my $journalctl_cmd = &has_command('journalctl');
return () if (!$journalctl_cmd);
my $eflags = "";
$eflags = " --reverse" if ($config{'reverse'});
my $jver = &get_journalctl_version();
$eflags .= " --no-hostname" if (!$config{'showhost'} && $jver && $jver >= 239);
$journalctl_cmd = "journalctl$eflags";
my @rs = (
	{ 'cmd' => "$journalctl_cmd --lines $lines",
	  'desc' => $text{'journal_journalctl'},
	  'id' => "journal-1", },
	{ 'cmd' => "$journalctl_cmd --lines $lines --catalog ",
	  'desc' => $text{'journal_expla_journalctl'},
	  'id' => "journal-2", },
	{ 'cmd' => "$journalctl_cmd --lines $lines --priority alert..emerg",
	  'desc' => $text{'journal_journalctl_alert_emerg'},
	  'id' => "journal-3", },
	{ 'cmd' => "$journalctl_cmd --lines $lines --priority err..crit",
	  'desc' => $text{'journal_journalctl_err_crit'},
	  'id' => "journal-4", },
	{ 'cmd' => "$journalctl_cmd --lines $lines --priority notice..warning",
	  'desc' => $text{'journal_journalctl_notice_warning'},
	  'id' => "journal-5", },
	{ 'cmd' => "$journalctl_cmd --lines $lines --priority debug..info",
	  'desc' => $text{'journal_journalctl_debug_info'},
	  'id' => "journal-6", },
	{ 'cmd' => "$journalctl_cmd --lines $lines --dmesg ",
	  'desc' => $text{'journal_journalctl_dmesg'},
	  'id' => "journal-7", } );

# Add more units from config if exists on the system
my (%ucache, %uread);
my $units_cache = "$module_config_directory/units.cache";
&read_file($units_cache, \%ucache);
if (!%ucache) {
	my $out = &backquote_command("systemctl list-units --all --no-legend ".
			"--no-pager");
	foreach my $line (split(/\r?\n/, $out)) {
		$line =~ s/^[^a-z0-9\-\_\.]+//i;
		my ($unit, $desc) = (split(/\s+/, $line, 5))[0, 4];
		$uread{$unit} = $desc;
		}
	}
# All units
%ucache = %uread if (%uread);
# If forced to select, return full list
if ($fselect) {
	my %units = %uread ? %uread : %ucache;
	foreach my $u (sort keys %units) {
		my $uname = $u;
		$uname =~ s/\\x([0-9A-Fa-f]{2})/pack('H2', $1)/eg;
		push(@rs, { 'cmd' => "$journalctl_cmd --lines ".
			    "$lines --unit $u",
			    'desc' => $uname,
			    'id' => "journal-a-$u", });
		}
	}
# Otherwise, return only the pointer
# element for the index page
else {
	push(@rs, 
		{ 'cmd' => "$journalctl_cmd --lines $lines --unit",
		  'desc' => $text{'journal_journalctl_unit'},
		  'id' => "journal-u" });
	}

# Save cache
if (%uread) {
	&lock_file($units_cache);
	&write_file($units_cache, \%ucache);
	&unlock_file($units_cache);
	}
return @rs;
}

# clear_systemctl_cache()
# Clear the cache of systemctl units
sub clear_systemctl_cache
{
unlink("$module_config_directory/units.cache");
}

# cleanup_destination(cmd)
# Returns a destination of some command cleaned up for display
sub cleanup_destination
{
my $cmd = shift;
$cmd =~ s/-n\s+\d+\s*//;
$cmd =~ s/\.service$//;
return $cmd;
}

# cleanup_description(desc)
# Returns a description cleaned up for display
sub cleanup_description
{
my $desc = shift;
$desc =~ s/\s+\(Virtualmin\)//;
return $desc;
}

# fix_clashing_description(description, service)
# Returns known clashing descriptions fixed
sub fix_clashing_description
{
my ($desc, $serv) = @_;
# EL systems name for PHP FastCGI Process Manager is repeated
if ($serv =~ /php(\d+)-php-fpm/) {
	my $php_version = $1;
	$php_version = join(".", split(//, $php_version));
	$desc =~ s/PHP/PHP $php_version/;
	}
return $desc;
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
foreach my $f (@rv) {
	if ($f->{'file'} =~ /^(.*)\s*\|$/) {
		delete($f->{'file'});
		$f->{'cmd'} = $1;
		}
	}
return @rv;
}

# config_post_save
# Called after the module's configuration has been saved
sub config_post_save
{
&clear_systemctl_cache();
}

# catter_command(file)
# Given a file that may be compressed, returns the command to output it in
# plain text, or undef if impossible
sub catter_command
{
local ($l) = @_;
local $q = quotemeta($l);
if ($l =~ /\.gz$/i) {
	return &has_command("gunzip") ? "gunzip -c $q" : undef;
	}
elsif ($l =~ /\.Z$/i) {
	return &has_command("uncompress") ? "uncompress -c $q" : undef;
	}
elsif ($l =~ /\.bz2$/i) {
	return &has_command("bunzip2") ? "bunzip2 -c $q" : undef;
	}
elsif ($l =~ /\.xz$/i) {
	return &has_command("xz") ? "xz -d -c $q" : undef;
	}
else {
	return "cat $q";
	}
}

# get_journalctl_version()
# Returns the version of journalctl
sub get_journalctl_version
{
my $bin = &has_command('journalctl');
my $out = &backquote_command("\"$bin\" --version 2>&1");
if ($out =~ /systemd\s+([0-9]+(?:\.[0-9A-Za-z\-\+]+)*)/) {
	return $1;
	}
return undef;
}

1;

