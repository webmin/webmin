=head1 backup-config-lib.pl

Functions for creating configuration file backups. Some example code :

 foreign_require('backup-config', 'backup-config-lib.pl');
 @backups = backup_config::list_backups();
 ($apache_backup) = grep { $_->{'mods'} eq 'apache' } @backups;
 $apache_backup->{'dest'} = '/tmp/apache.tar.gz';
 &backup_config::save_backup($apache_backup);

=cut

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
use WebminCore;
our (%text, $module_config_directory, %config);
&init_config();
&foreign_require("cron", "cron-lib.pl");

our $cron_cmd = "$module_config_directory/backup.pl";
our $backups_dir = "$module_config_directory/backups";
our $manifests_dir = "/tmp/backup-config-manifests";

=head2 list_backup_modules

Returns details of all modules that allow backups, each of which is a hash
ref in the same format as returned by get_module_info.

=cut
sub list_backup_modules
{
my ($m, @rv);
foreach $m (&get_all_module_infos()) {
	my $mdir = &module_root_directory($m->{'dir'});
	if (&check_os_support($m) &&
	    -r "$mdir/backup_config.pl") {
		push(@rv, $m);
		}
	}
return sort { $a->{'desc'} cmp $b->{'desc'} } @rv;
}

=head2 list_backups

Returns a list of all configured backups, each of which is a hash ref with
at least the following keys :

=item mods - Space-separate list of modules to include.

=item dest - Destination file, FTP or SSH server.

=item configfile - Set to 1 if /etc/webmin/modulename files are included.

=item nofiles - Set to 1 if server config files (like httpd.conf) are NOT included.

=item others - A tab-separated list of other files to include.

=item email -Email address to notify.

=item emode - Set to 0 to send email only on failure, 1 to always send.

=item sched - Set to 1 if regular scheduled backups are enabled.

=item mins,hours,days,months,weekdays - Cron-style specification of backup time.

=cut
sub list_backups
{
my (@rv, $f);
opendir(DIR, $backups_dir) || return ();
foreach $f (sort { $a cmp $b } readdir(DIR)) {
	next if ($f !~ /^(\S+)\.backup$/);
	push(@rv, &get_backup($1));
	}
closedir(DIR);
return @rv;
}

=head2 get_backup(id)

Given a unique backup ID, returns a hash ref containing its details, in the
same format as list_backups.

=cut
sub get_backup
{
my %backup;
&read_file("$backups_dir/$_[0].backup", \%backup) || return undef;
$backup{'id'} = $_[0];
return \%backup;
}

=head2 save_backup(&backup)

Given a hash ref containing backup details, saves them to disk. Must be in
the same format as returned by list_backups, except for the ID which will be
randomly assigned if missing.

=cut
sub save_backup
{
$_[0]->{'id'} ||= time().$$;
mkdir($backups_dir, 0700);
&lock_file("$backups_dir/$_[0]->{'id'}.backup");
&write_file("$backups_dir/$_[0]->{'id'}.backup", $_[0]);
&unlock_file("$backups_dir/$_[0]->{'id'}.backup");
}

=head2 delete_backup(&backup)

Deletes the backup whose details are in the given hash ref.

=cut
sub delete_backup
{
&unlink_logged("$backups_dir/$_[0]->{'id'}.backup");
}

=head2 parse_backup_url(string)

Converts a URL like ftp:// or a filename into its components. These are
user, pass, host, page, port (optional)

=cut
sub parse_backup_url
{
if ($_[0] && $_[0] =~ /^ftp:\/\/([^:]*):([^\@]*)\@([^\/:]+)(:(\d+))?(\/.*)$/) {
	return (1, $1, $2, $3, $6, $5);
	}
elsif ($_[0] &&
       $_[0] =~ /^ssh:\/\/([^:]*):([^\@]*)\@([^\/:]+)(:(\d+))?(\/.*)$/) {
	return (2, $1, $2, $3, $6, $5);
	}
elsif ($_[0] && $_[0] =~ /^upload:(.*)$/) {
	return (3, undef, undef, undef, $1);
	}
elsif ($_[0] && $_[0] =~ /^download:$/) {
	return (4, undef, undef, undef, undef);
	}
else {
	return (0, undef, undef, undef, $_[0]);
	}
}

=head2 show_backup_destination(name, value, [local-mode])

Returns HTML for a field for selecting a local or FTP file.

=cut
sub show_backup_destination
{
my ($mode, $user, $pass, $server, $path, $port) = &parse_backup_url($_[1]);
my $rv;
$rv .= "<table id='show_backup_destination' cellpadding=1 cellspacing=0>";

# Local file field
$rv .= "<tr><td>".&ui_oneradio("$_[0]_mode", 0, undef, $mode == 0)."</td>\n";
$rv .= "<td>$text{'backup_mode0'}&nbsp;</td><td colspan='3'>".
	&ui_textbox("$_[0]_file", $mode == 0 ? $path : "", 60).
	" ".&file_chooser_button("$_[0]_file")."</td> </tr>\n";

# FTP file fields
$rv .= "<tr><td>".&ui_oneradio("$_[0]_mode", 1, undef, $mode == 1)."</td>\n";
$rv .= "<td>$text{'backup_mode1'}&nbsp;</td><td>".
	&ui_textbox("$_[0]_server", $mode == 1 ? $server : undef, 20).
	"</td>\n";
$rv .= "<td>&nbsp;$text{'backup_path'}&nbsp;</td><td> ".
	&ui_textbox("$_[0]_path", $mode == 1 ? $path : undef, 20).
	"</td> </tr>\n";
$rv .= "<tr> <td></td>\n";
$rv .= "<td>$text{'backup_login'}&nbsp;</td><td> ".
	&ui_textbox("$_[0]_user", $mode == 1 ? $user : undef, 20).
	"</td>\n";
$rv .= "<td>&nbsp;$text{'backup_pass'}&nbsp;</td><td> ".
	&ui_password("$_[0]_pass", $mode == 1 ? $pass : undef, 20).
	"</td> </tr>\n";
$rv .= "<tr> <td></td>\n";
$rv .= "<td colspan='4'>$text{'backup_port'} ".
	&ui_opt_textbox("$_[0]_port", $mode == 1 ? $port : undef, 5,
			$text{'default'})."</td> </tr>\n";

# SCP file fields
$rv .= "<tr><td>".&ui_oneradio("$_[0]_mode", 2, undef, $mode == 2)."</td>\n";
$rv .= "<td>$text{'backup_mode2'}&nbsp;</td><td>".
	&ui_textbox("$_[0]_sserver", $mode == 2 ? $server : undef, 20).
	"</td>\n";
$rv .= "<td>&nbsp;$text{'backup_path'}&nbsp;</td><td> ".
	&ui_textbox("$_[0]_spath", $mode == 2 ? $path : undef, 20).
	"</td> </tr>\n";
$rv .= "<tr> <td></td>\n";
$rv .= "<td>$text{'backup_login'}&nbsp;</td><td> ".
	&ui_textbox("$_[0]_suser", $mode == 2 ? $user : undef, 20).
	"</td>\n";
$rv .= "<td>&nbsp;$text{'backup_pass'}&nbsp;</td><td> ".
	&ui_password("$_[0]_spass", $mode == 2 ? $pass : undef, 20).
	"</td> </tr>\n";
$rv .= "<tr> <td></td>\n";
$rv .= "<td colspan='4'>$text{'backup_port'} ".
	&ui_opt_textbox("$_[0]_sport", $mode == 2 ? $port : undef, 5,
			$text{'default'})."</td> </tr>\n";

if ($_[2] == 1) {
	# Uploaded file field
	$rv .= "<tr><td>".&ui_oneradio("$_[0]_mode", 3, undef, $mode == 3).
		"</td>\n";
	$rv .= "<td colspan=4>$text{'backup_mode3'} ".
		&ui_upload("$_[0]_upload", 40).
		"</td> </tr>\n";
	}
elsif ($_[2] == 2) {
	# Output to browser option
	$rv .= "<tr><td>".&ui_oneradio("$_[0]_mode", 4, undef, $mode == 4).
		"</td>\n";
	$rv .= "<td colspan=4>$text{'backup_mode4'}</td> </tr>\n";
	}

$rv .= "</table>\n";
return $rv;
}

=head2 parse_backup_destination(name, &in)

Returns a backup destination string, or calls error.

=cut
sub parse_backup_destination
{
my %in = %{$_[1]};
my $mode = $in{"$_[0]_mode"} || 0;
if ($mode == 0) {
	# Local file
	$in{"$_[0]_file"} && $in{"$_[0]_file"} =~ /^\/\S/ ||
		&error($text{'backup_edest'});
	return $in{"$_[0]_file"};
	}
elsif ($mode == 1) {
	# FTP server
	&to_ipaddress($in{"$_[0]_server"}) ||
	  &to_ip6address($in{"$_[0]_server"}) ||
	    &error($text{'backup_eserver1'});
	$in{"$_[0]_path"} =~ /^\/\S/ || &error($text{'backup_epath'});
	$in{"$_[0]_user"} =~ /^[^:]*$/ || &error($text{'backup_euser'});
	$in{"$_[0]_pass"} =~ /^[^\@]*$/ || &error($text{'backup_epass'});
	$in{"$_[0]_port_def"} || $in{"$_[0]_port"} =~ /^\d+$/ ||
		&error($text{'backup_eport'});
	return "ftp://".$in{"$_[0]_user"}.":".$in{"$_[0]_pass"}."\@".
	       $in{"$_[0]_server"}.
	       ($in{"$_[0]_port_def"} ? "" : ":".$in{"$_[0]_port"}).
	       $in{"$_[0]_path"};
	}
elsif ($mode == 2) {
	# SSH server
	&to_ipaddress($in{"$_[0]_sserver"}) ||
	  &to_ip6address($in{"$_[0]_sserver"}) ||
	    &error($text{'backup_eserver2'});
	$in{"$_[0]_spath"} =~ /^\/\S/ || &error($text{'backup_epath2'});
	$in{"$_[0]_suser"} =~ /^[^:]*$/ || &error($text{'backup_euser'});
	$in{"$_[0]_spass"} =~ /^[^\@]*$/ || &error($text{'backup_epass'});
	$in{"$_[0]_sport_def"} || $in{"$_[0]_sport"} =~ /^\d+$/ ||
		&error($text{'backup_esport'});
	return "ssh://".$in{"$_[0]_suser"}.":".$in{"$_[0]_spass"}."\@".
	       $in{"$_[0]_sserver"}.
	       ($in{"$_[0]_sport_def"} ? "" : ":".$in{"$_[0]_sport"}).
	       $in{"$_[0]_spath"};
	}
elsif ($mode == 3) {
	# Uploaded file .. save as temp file?
	$in{"$_[0]_upload"} || &error($text{'backup_eupload'});
	return "upload:$_[0]_upload";
	}
elsif ($mode == 4) {
	return "download:";
	}
}

=head2 execute_backup(&modules, dest, &size, &files, include-webmin, exclude-files, &others)

Backs up the configuration files for the modules to the selected destination.
The backup is simply a tar file of config files. Returns undef on success,
or an error message on failure.

=cut
sub execute_backup
{
# Work out modules we can use
my @mods;
foreach my $m (@{$_[0]}) {
	my $mdir = &module_root_directory($m);
	if ($m && &foreign_check($m) && -r "$mdir/backup_config.pl") {
		push(@mods, $m);
		}
	}

# Work out where to write to
my ($mode, $user, $pass, $host, $path, $port) = &parse_backup_url($_[1]);
my $file;
if ($mode == 0) {
	$file = &date_subs($path);
	}
else {
	$file = &transname();
	}

# Get module descriptions
my $m;
my %desc;
foreach $m (@mods) {
	my %minfo = &get_module_info($m);
	$desc{$m} = $minfo{'desc'};
	}

my @files;
my %manifestfiles;
if (!$_[5]) {
	# Build list of all files to save from modules
	foreach my $m (@mods) {
		&foreign_require($m, "backup_config.pl");
		my @mfiles = &foreign_call($m, "backup_config_files");
		foreach my $f (@mfiles) {
			next if (!$f);
			if (-d $f) {
				# A directory .. recursively expand
				foreach my $sf (&expand_directory($f)) {
					next if (!$sf);
					push(@files, $sf);
					push(@{$manifestfiles{$m}}, $sf);
					}
				}
			else {
				# Just one file
				push(@files, $f);
				push(@{$manifestfiles{$m}}, $f);
				}
			}
		}
	}

# Add module config files and custom langs
if ($_[4]) {
	foreach $m (@mods) {
		my @cfiles = ( "$config_directory/$m/config" );
		push(@cfiles, glob("$config_directory/$m/custom-lang*"));
		push(@files, @cfiles);
		push(@{$manifestfiles{$m}}, @cfiles);
		}
	}

# Add other files
foreach my $f (@{$_[6]}) {
	next if (!$f);
	if (-d $f) {
		# A directory .. recursively expand
		foreach my $sf (&expand_directory($f)) {
			next if (!$sf);
			push(@files, $sf);
			push(@{$manifestfiles{"other"}}, $sf);
			}
		}
	else {
		# Just one file
		push(@files, $f);
		push(@{$manifestfiles{"other"}}, $f);
		}
	}

# Save the manifest files
&execute_command("rm -rf ".quotemeta($manifests_dir));
mkdir($manifests_dir, 0755);
my @manifests;
foreach $m (@mods, "_others") {
	next if (!defined($manifestfiles{$m}));
	my $man = "$manifests_dir/$m";
	my $fh;
	&open_tempfile($fh, ">$man");
	&print_tempfile($fh, map { "$_\n" } @{$manifestfiles{$m}});
	&close_tempfile($fh);
	push(@manifests, $man);
	}

# Make sure we have something to do
@files = grep { $_ && -e $_ } @files;
@files || (return $text{'backup_enone'});

if (!$_[5]) {
	# Call all module pre functions
	my $m;
	foreach $m (@mods) {
		if (&foreign_defined($m, "pre_backup")) {
			my $err = &foreign_call($m, "pre_backup", \@files);
			if ($err) {
				return &text('backup_epre', $desc{$m}, $err);
				}
			}
		}
	}

# Make the tar (possibly .gz) file
my $filestemp = &transname();
my $fh;
&open_tempfile($fh, ">$filestemp");
foreach my $f (&unique(@files), @manifests) {
	my $frel = $f;
	$frel =~ s/^\///;
	&print_tempfile($fh, $frel."\n");
	}
&close_tempfile($fh);
my $qfile = quotemeta($file);
my $out;
if (&has_command("gzip")) {
	&execute_command("cd / ; tar cfT - $filestemp | gzip -c >$qfile",
			 undef, \$out, \$out);
	}
else {
	&execute_command("cd / ; tar cfT $qfile $filestemp",
			 undef, \$out, \$out);
	}
my $ex = $?;
&unlink_file($filestemp);
if ($ex) {
	&unlink_file($file) if ($mode != 0);
	return &text('backup_etar', "<pre>$out</pre>");
	}
my @st = stat($file);
${$_[2]} = $st[7] if ($_[2]);
@{$_[3]} = &unique(@files) if ($_[3]);
&set_ownership_permissions(undef, undef, 0600, $file);

if (!$_[5]) {
	# Call all module post functions
	foreach $m (@mods) {
		if (&foreign_defined($m, "post_backup")) {
			&foreign_call($m, "post_backup", \@files);
			}
		}
	}

if ($mode == 1) {
	# FTP upload to destination
	my $err;
	&ftp_upload($host, &date_subs($path), $file, \$err, undef,
		    $user, $pass, $port);
	&unlink_file($file);
	return $err if ($err);
	}
elsif ($mode == 2) {
	# SCP to destination
	my $err;
	&scp_copy($file, "$user\@$host:".&date_subs($path), $pass, \$err,$port);
	&unlink_file($file);
	return $err if ($err);
	}

return undef;
}

=head2 execute_restore(&mods, source, &files, apply, [show-only],
		       [&other-files])

Restore configuration files from the specified source for the listed modules.
Returns undef on success, or an error message.

=cut
sub execute_restore
{
my ($mods, $src, $files, $apply, $show, $others) = @_;

# Fetch file if needed
my ($mode, $user, $pass, $host, $path, $port) = &parse_backup_url($src);
my $file;
if ($mode == 0) {
	$file = $path;
	}
else {
	$file = &transname();
	if ($mode == 2) {
		# Download with SCP
		my $err;
		&scp_copy("$user\@$host:$path", $file, $pass, \$err, $port);
		if ($err) {
			&unlink_file($file);
			return $err;
			}
		}
	elsif ($mode == 1) {
		# Download with FTP
		my $err;
		&ftp_download($host, $path, $file, \$err, undef,
			      $user, $pass, $port);
		if ($err) {
			&unlink_file($file);
			return $err;
			}
		}
	}

# Validate archive
open(FILE, $file);
my $two;
read(FILE, $two, 2);
close(FILE);
my $qfile = quotemeta($file);
my $gzipped = ($two eq "\037\213");
my $cmd;
if ($gzipped) {
	# Gzipped
	&has_command("gunzip") || return $text{'backup_egunzip'};
	$cmd = "gunzip -c $qfile | tar tf -";
	}
else {
	$cmd = "tar tf $qfile";
	}
my $out;
&execute_command($cmd, undef, \$out, \$out, 0, 1);
if ($?) {
	&unlink_file($file) if ($mode != 0);
	return &text('backup_euntar', "<pre>$out</pre>");
	}
my @tarfiles = map { "/$_" } split(/\r?\n/, $out);
my %tarfiles = map { $_, 1 } @tarfiles;

# Extract manifests for each module
my %hasmod = map { $_, 1 } @$mods;
$hasmod{"_others"} = 1;
&execute_command("rm -rf ".quotemeta($manifests_dir));
my $rel_manifests_dir = $manifests_dir;
$rel_manifests_dir =~ s/^\///;
if ($gzipped) {
	&execute_command("cd / ; gunzip -c $qfile | tar xf - $rel_manifests_dir", undef, \$out, \$out);
	}
else {
	&execute_command("cd / ; tar xf $qfile $rel_manifests_dir", undef, \$out, \$out);
	}
opendir(DIR, $manifests_dir);
my $m;
my %mfiles;
my @files;
while($m = readdir(DIR)) {
	next if ($m eq "." || $m eq ".." || !$hasmod{$m});
	open(MAN, "$manifests_dir/$m");
	my @mfiles;
	while(<MAN>) {
		s/\r|\n//g;
		if ($tarfiles{$_}) {
			push(@mfiles, $_);
			}
		}
	close(MAN);
	$mfiles{$m} = \@mfiles;
	push(@files, @mfiles);
	}
closedir(DIR);
push(@files, @$others) if ($others);
if (!@files) {
	&unlink_file($file) if ($mode != 0);
	return $text{'backup_enone2'};
	}

# Get descriptions for each module
my %desc;
foreach my $m (@$mods) {
	my %minfo = &get_module_info($m);
	$desc{$m} = $minfo{'desc'};
	}

# Call module pre functions
foreach my $m (@$mods) {
	my $mdir = &module_root_directory($m);
	if ($m && &foreign_check($m) && !$show &&
	    -r "$mdir/backup_config.pl") {
		&foreign_require($m, "backup_config.pl");
		if (&foreign_defined($m, "pre_restore")) {
			my $err = &foreign_call($m, "pre_restore", \@files);
			if ($err) {
				&unlink_file($file) if ($mode != 0);
				return &text('backup_epre2', $desc{$m}, $err);
				}
			}
		}
	}

# Lock all files being extracted
if (!$show) {
	my $f;
	foreach $f (@files) {
		&lock_file($f);
		}
	}

# Extract contents (only files specified by manifests)
my $flag = $show ? "t" : "xv";
my $qfiles = join(" ", map { s/^\///; quotemeta($_) } &unique(@files));
if ($gzipped) {
	&execute_command("cd / ; gunzip -c $qfile | tar ${flag}f - $qfiles",
			 undef, \$out, \$out);
	}
else {
	&execute_command("cd / ; tar ${flag}f $qfile $qfiles",
			 undef, \$out, \$out);
	}
my $ex = $?;

# Un-lock all files being extracted
if (!$show) {
	my $f;
	foreach $f (@files) {
		&unlock_file($f);
		}
	}

# Check for tar error
if ($ex) {
	&unlink_file($file) if ($mode != 0);
	return &text('backup_euntar', "<pre>$out</pre>");
	}

if ($apply && !$show) {
	# Call all module apply functions
	foreach $m (@$mods) {
		if (&foreign_defined($m, "post_restore")) {
			&foreign_call($m, "post_restore", \@files);
			}
		}
	}

@$files = split(/\n/, $out);
return undef;
}

=head2 scp_copy(source, dest, password, &error, [port])

Copies a file from some source to a destination. One or the other can be
a server, like user@foo:/path/to/bar/

=cut
sub scp_copy
{
&foreign_require("proc", "proc-lib.pl");
my $cmd = "scp -r ".($_[4] ? "-P $_[4] " : "").
	  quotemeta($_[0])." ".quotemeta($_[1]);
my ($fh, $fpid) = &proc::pty_process_exec($cmd);
my $out;
while(1) {
	my $rv = &wait_for($fh, "password:", "yes\\/no", ".*\n");
	$out .= $wait_for_input;
	if ($rv == 0) {
		syswrite($fh, "$_[2]\n");
		}
	elsif ($rv == 1) {
		syswrite($fh, "yes\n");
		}
	elsif ($rv < 0) {
		last;
		}
	}
close($fh);
my $got = waitpid($fpid, 0);
if ($? || $out =~ /permission\s+denied/i) {
	${$_[3]} = "scp failed : <pre>$out</pre>";
	}
}

=head2 find_cron_job(&backup)

MISSING DOCUMENTATION

=cut
sub find_cron_job
{
my @jobs = &cron::list_cron_jobs();
my ($job) = grep { $_->{'user'} eq 'root' &&
		   $_->{'command'} eq "$cron_cmd $_[0]->{'id'}" } @jobs;
return $job;
}

=head2 nice_dest(destination, [subdates])

Returns a backup filename in a human-readable format, with dates substituted.

=cut
sub nice_dest
{
my ($url, $subdates) = @_;
my ($mode, $user, $pass, $server, $path, $port) = &parse_backup_url($url);
if ($subdates) {
	$path = &date_subs($path);
	}
if ($mode == 0) {
	return "<tt>$path</tt>";
	}
elsif ($mode == 1) {
	return &text($port ? 'nice_ftpp' : 'nice_ftp',
		     "<tt>$server</tt>", "<tt>$path</tt>",
		     $port ? "<tt>$port</tt>" : "");
	}
elsif ($mode == 2) {
	return &text($port ? 'nice_sshp' : 'nice_ssh',
		     "<tt>$server</tt>", "<tt>$path</tt>",
		     $port ? "<tt>$port</tt>" : "");
	}
elsif ($mode == 3) {
	return $text{'nice_upload'};
	}
elsif ($mode == 4) {
	return $text{'nice_download'};
	}
}

=head2 date_subs(string)

Given a string with strftime-style format characters in it like %Y and %S,
replaces them with the correct values for the current date and time.

=cut
sub date_subs
{
my ($path) = @_;
my $rv;
if ($config{'date_subs'}) {
        eval "use POSIX";
        eval "use posix" if ($@);
        my @tm = localtime(time());
        $rv = strftime($path, @tm);
        }
else {
	$rv = $path;
        }
if ($config{'webmin_subs'}) {
	$rv = &substitute_template($rv, { });
	}
return $rv;
}

=head2 show_backup_what(name, webmin?, nofiles?, others)

Returns HTML for selecting what gets included in a backup.

=cut
sub show_backup_what
{
my ($name, $webmin, $nofiles, $others) = @_;
$others ||= "";
return &ui_checkbox($name."_webmin", 1, $text{'edit_webmin'}, $webmin)."\n".
       &ui_checkbox($name."_nofiles", 1, $text{'edit_nofiles'}, !$nofiles)."\n".
       &ui_checkbox($name."_other", 1, $text{'edit_other'}, $others)."<br>".
       &ui_textarea($name."_files", join("\n", split(/\t+/, $others)), 3, 50);
}

=head2 parse_backup_what(name, &in)

Returns the webmin and nofiles flags, and a tab-separated list of other
files to include.

=cut
sub parse_backup_what
{
my ($name, $in) = @_;
my $webmin = $in->{$name."_webmin"};
my $nofiles = !$in->{$name."_nofiles"};
$in->{$name."_files"} =~ s/\r//g;
my $others = $in->{$name."_other"} ?
	join("\t", split(/\n+/, $in->{$name."_files"})) : undef;
$webmin || !$nofiles || $others || &error($text{'save_ewebmin'});
return ($webmin, $nofiles, $others);
}

=head2 expand_directory(directory)

Given a directory, return a list of full paths to all files within it.

=cut
sub expand_directory
{
my ($dir) = @_;
my @rv;
opendir(EXPAND, $dir);
my @sf = readdir(EXPAND);
closedir(EXPAND);
foreach my $sf (@sf) {
	next if ($sf eq "." || $sf eq "..");
	my $path = "$dir/$sf";
	if (-l $path || !-d $path) {
		push(@rv, $path);
		}
	elsif (-d $path) {
		push(@rv, &expand_directory($path));
		}
	}
return @rv;
}

1;

