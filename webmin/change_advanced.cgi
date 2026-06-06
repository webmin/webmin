#!/usr/local/bin/perl
# Save advanced options

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'advanced_err'});
&get_miniserv_config(\%miniserv);

# Permissions used for newly created Webmin temp directories.
my $advanced_temp_dir_perms = 0755;
my $advanced_temp_dir_perms_text = sprintf("%04o", $advanced_temp_dir_perms);
my %advanced_system_temp_dirs = map { $_ => 1 }
	( "/dev/shm", "/tmp", "/var/tmp", "/usr/tmp" );

# Save global temp dir setting
if ($in{'tempdir_def'}) {
	delete($gconfig{'tempdir'});
	}
else {
	&allowed_temp_dir($in{'tempdir'}) ||
		&error(&text('advanced_etempallowed', $in{'tempdir'}));
	$in{'tempdir'} = &setup_advanced_temp_dir(
		$in{'tempdir'}, $text{'advanced_etemp'});
	$gconfig{'tempdir'} = $in{'tempdir'};
	}

# Save temp clearing options
$gconfig{'tempdirdelete'} = $in{'tempdirdelete'};
if ($in{'tempdelete_def'}) {
	$gconfig{'tempdelete_days'} = '';
	}
else {
	$in{'tempdelete'} =~ /^[0-9\.]+$/ ||
		&error($text{'advanced_etempdelete'});
	$gconfig{'tempdelete_days'} = $in{'tempdelete'};
	}

# Save per-module temp dirs
for($i=0; defined($tmod = $in{'tmod_'.$i}); $i++) {
	next if (!$tmod);
	$tdir = $in{'tdir_'.$i};
	%minfo = &get_module_info($tmod);
	&allowed_temp_dir($tdir) ||
		&error(&text('advanced_etempallowed', $tdir));
	$tdir = &setup_advanced_temp_dir(
		$tdir, &text('advanced_etdir', $minfo{'desc'}));
	push(@tdirs, [ $tmod, $tdir ]);
	}
&save_tempdirs(\%gconfig, \@tdirs);

# Save umask
if ($in{'umask_def'}) {
	delete($gconfig{'umask'});
	}
else {
	$in{'umask'} =~ /^[0-7]{3}$/ || &error($text{'advanced_eumask'});
	$gconfig{'umask'} = $in{'umask'};
	}

# Save chattr
if (defined($in{'chattr'})) {
	$gconfig{'chattr'} = $in{'chattr'};
	}

# Save nice level
if ($in{'nice_def'}) {
	delete($gconfig{'nice'});
	}
else {
	$gconfig{'nice'} = $in{'nice'};
	}

# Save scheduling class
if (defined($in{'sclass'})) {
	$gconfig{'sclass'} = $in{'sclass'};
	$gconfig{'sprio'} = $in{'sprio'};
	}

# Save HTTP headers
@hl = ( );
foreach my $l (split(/\r?\n/, $in{'headers'})) {
	$l =~ /^\S+:\s+\S.*$/ || &error($text{'advanced_eheader'});
	push(@hl, $l);
	}
$gconfig{'extra_headers'} = join("\t", @hl);

# Sort config file's keys alphabetically
if (defined($in{'sortconfigs'})) {
	$gconfig{'sortconfigs'} = $in{'sortconfigs'};
	}

&lock_file("$config_directory/config");
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");

if (defined($in{'preload'})) {
	# Save preload option, forcing new mode
	if ($in{'preload'}) {
		$miniserv{'premodules'} = 'WebminCore';
		}
	else {
		delete($miniserv{'premodules'});
		}
	&save_preloads(\%miniserv, [ ]);
	}

# Save pre-cache option
if ($in{'precache_mode'} == 0) {
	$miniserv{'precache'} = 'none';
	}
elsif ($in{'precache_mode'} == 1) {
	$miniserv{'precache'} = '';
	}
else {
	$in{'precache'} =~ /\S/ || &error($text{'advanced_eprecache'});
	$miniserv{'precache'} = $in{'precache'};
	}

# Save buffer size
if ($in{'bufsize_def'}) {
	delete($miniserv{'bufsize'});
	}
else {
	$in{'bufsize'} =~ /^\d+$/ && $in{'bufsize'} > 0 ||
		&error($text{'advanced_ebufsize'});
	$miniserv{'bufsize'} = $in{'bufsize'};
	}

# Save buffer size
if ($in{'bufsize_binary_def'}) {
	delete($miniserv{'bufsize_binary'});
	}
else {
	$in{'bufsize_binary'} =~ /^\d+$/ && $in{'bufsize_binary'} > 0 ||
		&error($text{'advanced_ebufsize_binary'});
	$miniserv{'bufsize_binary'} = $in{'bufsize_binary'};
	}

&lock_file($ENV{'MINISERV_CONFIG'});
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});

&show_restart_page();
&webmin_log("advanced");


sub allowed_temp_dir
{
my ($t) = @_;
my $dir = $t;
$dir =~ s/\/+$// if ($dir ne "/");
return $dir eq "/" || $dir =~ /^\/[^\/]+$/ ||
       $advanced_system_temp_dirs{$dir} ? 0 : 1;
}

# Create a configured Webmin temp directory if needed, and validate existing
# path components without changing permissions on directories the user made.
sub setup_advanced_temp_dir
{
my ($dir, $missing_error) = @_;
$dir =~ /\S/ || &error($missing_error);
$dir =~ s/\/+$// if ($dir ne "/");
$dir =~ /\S/ || &error($missing_error);
if (&advanced_temp_dir_is_windows($dir)) {
	if (!-d $dir) {
		&make_dir($dir, $advanced_temp_dir_perms, 1) ||
			&error(&text('advanced_etempmkdir', $dir, "$!"));
		-d $dir ||
			&error(&text('advanced_etempmkdir', $dir, "$!"));
		}
	return $dir;
	}
if ($dir =~ /^\//) {
	my $sdir = &simplify_path($dir);
	defined($sdir) || &error($missing_error);
	$dir = $sdir;
	}
&allowed_temp_dir($dir) ||
	&error(&text('advanced_etempallowed', $dir));

# Walk the path so existing parents are checked, while missing parents and
# the final temp directory are created with Webmin's expected mode.
my $path = $dir =~ /^\// ? "/" : "";
foreach my $part (split(/\/+/, $dir)) {
	next if ($part eq "");
	$path = $path eq "/" ? "/$part" :
		$path eq "" ? $part : "$path/$part";
	my $final = $path eq $dir;
	my @st = lstat($path);
	if (@st) {
		-d _ || &error(&text('advanced_etempparent', $path));
		if ($final) {
			&advanced_temp_dir_perms_ok($path) ||
				&error(&text('advanced_etempperms', $path,
					     $advanced_temp_dir_perms_text));
			}
		else {
			&advanced_temp_parent_dir_perms_ok($path) ||
				&error(&text('advanced_etempparentperms',
					     $path));
			}
		next;
		}
	&make_dir($path, $advanced_temp_dir_perms) ||
		&error(&text('advanced_etempmkdir', $path, "$!"));
	&advanced_temp_dir_perms_ok($path) ||
		&error(&text('advanced_etempchmod', $path,
			     $advanced_temp_dir_perms_text, "$!"));
	}
&advanced_temp_dir_perms_ok($dir) ||
	&error(&text('advanced_etempperms', $dir,
		     $advanced_temp_dir_perms_text));
return $dir;
}

# Check the final configured temp directory. It must be Webmin-private.
sub advanced_temp_dir_perms_ok
{
my ($dir) = @_;
my @st = lstat($dir);
return 0 if (!@st || !-d _);
return 0 if ($st[4] != $<);
my $mode = $st[2] & 07777;
return $mode == $advanced_temp_dir_perms;
}

# Existing parents only need to be searchable by group and others. The final
# temp directory itself is checked more strictly above.
sub advanced_temp_parent_dir_perms_ok
{
my ($dir) = @_;
my @st = lstat($dir);
return 0 if (!@st || !-d _);
my $mode = $st[2] & 07777;
return 0 if (($mode & 0011) != 0011);
return 1;
}

# Windows temp directories are only checked for existence and created if needed.
sub advanced_temp_dir_is_windows
{
my ($dir) = @_;
return $gconfig{'os_type'} eq 'windows' || $dir =~ /^[a-z]:/i;
}
