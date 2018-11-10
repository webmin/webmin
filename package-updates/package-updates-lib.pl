# Functions for checking for updates to packages from YUM, APT or some other
# update system.

BEGIN { push(@INC, ".."); };
eval "use WebminCore;";
&init_config();
&foreign_require("software", "software-lib.pl");
&foreign_require("cron", "cron-lib.pl");
&foreign_require("webmin", "webmin-lib.pl");

$available_cache_file = &cache_file_path("available.cache");
$current_cache_file = &cache_file_path("current.cache");
$updates_cache_file = &cache_file_path("updates.cache");
$cron_cmd = "$module_config_directory/update.pl";

$yum_cache_file = &cache_file_path("yumcache");
$apt_cache_file = &cache_file_path("aptcache");
$yum_changelog_cache_dir = &cache_file_path("yumchangelog");

$update_progress_dir = "$module_var_directory/progress";

# cache_file_path(name)
# Returns a path in the /var directory unless the file already exists under
# /etc/webmin
sub cache_file_path
{
my ($name) = @_;
if (-e "$module_config_directory/$name") {
	return "$module_config_directory/$name";
	}
return "$module_var_directory/$name";
}

# get_software_packages()
# Fills in software::packages with list of installed packages (if missing),
# returns count.
sub get_software_packages
{
if (!$get_software_packages_cache) {
        %software::packages = ( );
	if (!defined(&software::list_packages)) {
		return 0;
		}
        $get_software_packages_cache = &software::list_packages();
        }
return $get_software_packages_cache;
}

# list_current(nocache)
# Returns a list of packages and versions for installed software. Keys are :
#  name - The my package name (ie. CSWapache2)
#  update - Name used to refer to it by the updates system (ie. apache2)
#  version - Version number
#  epoch - Epoch part of the version
#  desc - Human-readable description
sub list_current
{
my ($nocache) = @_;
if ($nocache || &cache_expired($current_cache_file)) {
	my $n = &get_software_packages();
	my @rv;
	for(my $i=0; $i<$n; $i++) {
		push(@rv, { 'name' => $software::packages{$i,'name'},
			    'update' => $software::packages{$i,'name'},
			    'version' =>
			      $software::packages{$i,'version'},
			    'epoch' =>
			      $software::packages{$i,'epoch'},
			    'desc' =>
			      $software::packages{$i,'desc'},
			    'system' => $software::update_system,
			});
		&fix_pkgadd_version($rv[$#rv]);
		}

	# Filter out dupes and sort by name
	@rv = &filter_duplicates(\@rv);

	&write_cache_file($current_cache_file, \@rv);
	return @rv;
	}
else {
	return &read_cache_file($current_cache_file);
	}
}

# list_available(nocache)
# Returns the names and versions of packages available from the update system
sub list_available
{
my ($nocache) = @_;
my $expired = &cache_expired($available_cache_file);
if ($nocache || $expired == 2 ||
    $expired == 1 && !&check_available_lock()) {
	# Get from update system
	my @rv;
	my @avail = &packages_available();
	foreach my $avail (@avail) {
		$avail->{'update'} = $avail->{'name'};
		$avail->{'name'} = &csw_to_pkgadd($avail->{'name'});
		push(@rv, $avail);
		}

	# Filter out dupes and sort by name
	@rv = &filter_duplicates(\@rv);

	if (!@rv) {
		# Failed .. fall back to cache
		@rv = &read_cache_file($available_cache_file);
		}
	&write_cache_file($available_cache_file, \@rv);
	return @rv;
	}
else {
	return &read_cache_file($available_cache_file);
	}
}

# check_available_lock()
# Returns 1 if the package update system is currently locked
sub check_available_lock
{
if ($software::update_system eq "yum") {
        return &check_pid_file("/var/run/yum.pid");
        }
return 0;
}

# filter_duplicates(&packages)
# Given a list of package structures, orders them by name and version number,
# and removes dupes with the same name
sub filter_duplicates
{
my ($pkgs) = @_;
my @rv = sort { $a->{'name'} cmp $b->{'name'} ||
	         &compare_versions($b, $a) } @$pkgs;
my %done;
return grep { !$done{$_->{'name'},$_->{'system'}}++ } @rv;
}

# cache_expired(file)
# Checks if some cache has expired. Returns 0 if OK, 1 if expired, 2 if
# totally missing.
sub cache_expired 
{
my ($file) = @_;
my @st = stat($file);
return 2 if (!@st);
if (!$config{'cache_time'} || time()-$st[9] > $config{'cache_time'}*60*60) {
        return 1;
        }
return 0;               
}                               

sub write_cache_file
{
my ($file, $arr) = @_;
eval "use Data::Dumper";
if (!$@) {
	&open_tempfile(FILE, ">$file");
	&print_tempfile(FILE, Dumper($arr));
	&close_tempfile(FILE);
	$read_cache_file_cache{$file} = $arr;
	}
}

# read_cache_file(file)
# Returns the contents of some cache file, as an array ref
sub read_cache_file
{
my ($file) = @_;
if (defined($read_cache_file_cache{$file})) {
	return @{$read_cache_file_cache{$file}};
	}
if (-r $file) {
	do $file;
	$read_cache_file_cache{$file} = $VAR1;
	return @$VAR1;
	}
return ( );
}

# compare_versions(&pkg1, &pk2)
# Returns -1 if the version of pkg1 is older than pkg2, 1 if newer, 0 if same.
sub compare_versions
{
my ($pkg1, $pkg2) = @_;
if ($pkg1->{'system'} eq 'webmin' && $pkg2->{'system'} eq 'webmin') {
	# Webmin module version compares are always numeric
	return $pkg1->{'version'} <=> $pkg2->{'version'};
	}
my $ec = $pkg1->{'epoch'} <=> $pkg2->{'epoch'};
if ($ec && ($pkg1->{'epoch'} eq '' || $pkg2->{'epoch'} eq '') &&
    $pkg1->{'system'} eq 'apt') {
	# On some Debian systems, we don't have any epoch
	$ec = undef;
	}
return $ec ||
       &software::compare_versions($pkg1->{'version'}, $pkg2->{'version'});
}

sub find_cron_job
{
my @jobs = &cron::list_cron_jobs();
my ($job) = grep { $_->{'user'} eq 'root' &&
		      $_->{'command'} eq $cron_cmd } @jobs;
return $job;
}

# packages_available()
# Returns a list of all available packages, as hash references with name and
# version keys. These come from the APT, YUM or CSW update system, if available.
# If not, nothing is returned.
sub packages_available
{
if (@packages_available_cache) {
        return @packages_available_cache;
        }
if (defined(&software::update_system_available)) {
	# From a decent package system
	my @rv = software::update_system_available();
	my %done;
	foreach my $p (@rv) {
		$p->{'system'} = $software::update_system;
		$p->{'version'} =~ s/,REV=.*//i;		# For CSW
		if ($p->{'system'} eq 'apt' && !$p->{'source'}) {
			$p->{'source'} =
			    $p->{'file'} =~ /virtualmin/i ? 'virtualmin' : 
			    $p->{'file'} =~ /debian/i ? 'debian' :
			    $p->{'file'} =~ /ubuntu/i ? 'ubuntu' : undef;
			}
		$done{$p->{'name'}} = $p;
		}
	if ($software::update_system eq "yum" &&
	    &has_command("up2date")) {
		# YUM is the package system select, but up2date is installed
		# too (ie. RHEL). Fetch its packages too..
		if (!$done_rhn_lib++) {
			do "../software/rhn-lib.pl";
			}
		my @rhnrv = &update_system_available();
		foreach my $p (@rhnrv) {
			$p->{'system'} = "rhn";
			my $d = $done{$p->{'name'}};
			if ($d) {
				# Seen already .. but is this better?
				if (&compare_versions($p, $d) > 0) {
					# Yes .. replace
					@rv = grep { $_ ne $d } @rv;
					push(@rv, $p);
					$done{$p->{'name'}} = $p;
					}
				}
			else {
				push(@rv, $p);
				$done{$p->{'name'}} = $p;
				}
			}
		}
	@packages_available_cache = @rv;
	return @rv;
	}
return ( );
}

sub supports_updates_available
{
return defined(&software::update_system_updates);
}

# updates_available(no-cache)
# Returns an array of hash refs of package updates available, according to
# the update system, with caching.
sub updates_available
{
my ($nocache) = @_;
if (!scalar(@updates_available_cache)) {
	if ($nocache || &cache_expired($updates_cache_file)) {
		# Get from original source
		@updates_available_cache = &software::update_system_updates();
		foreach my $a (@updates_available_cache) {
			$a->{'update'} = $a->{'name'};
			$a->{'system'} = $software::update_system;
			}
		&write_cache_file($updates_cache_file,
				  \@updates_available_cache);
		}
	else {
		# Use on-disk cache
		@updates_available_cache =
			&read_cache_file($updates_cache_file);
		}
	}
return @updates_available_cache;
}

# package_install(package-name, [system], [new-install])
# Install some package, either from an update system or from Webmin. Returns
# a list of updated package names.
sub package_install
{
my ($name, $system, $install) = @_;
my @rv;
my $pkg;

# First get from list of updates
($pkg) = grep { $_->{'update'} eq $name &&
		($_->{'system'} eq $system || !$system) }
	      sort { &compare_versions($b, $a) }
		   &list_possible_updates(0);
if (!$pkg) {
	# Then try list of all available packages
	($pkg) = grep { $_->{'update'} eq $name &&
			($_->{'system'} eq $system || !$system) }
		      sort { &compare_versions($b, $a) }
			   &list_available(0);
	}
if (!$pkg && $install) {
	# Assume that it will exist
	$pkg = { 'system' => $system || $software::update_system,
		 'name' => $name };
	}
if (!$pkg) {
	print &text('update_efindpkg', $name),"<p>\n";
	return ( );
	}
if (defined(&software::update_system_install)) {
	# Using some update system, like YUM or APT
	&clean_environment();
	if ($software::update_system eq $pkg->{'system'}) {
		# Can use the default system
		if ($name eq "apache2" &&
		    $pkg->{'system'} eq 'apt') {
			# If updating the apache2 package on an apt system
			# and apache2-mpm-prefork is installed, also update it
			# so that ubuntu doesn't pull in the apache2-mpm-worker
			# instead, which breaks PHP :-(
			local @pinfo = &software::package_info(
					"apache2-mpm-prefork");
			if (@pinfo) {
				$name .= " apache2-mpm-prefork";
				}
			}
		@rv = &software::update_system_install($name, undef, 1);
		}
	else {
		# Another update system exists!! Use it..
		if (!$done_rhn_lib++) {
			do "../software/$pkg->{'system'}-lib.pl";
			}
		if (!$done_rhn_text++) {
			%text = ( %text, %software::text );
			}
		@rv = &update_system_install($name, undef, 1);
		}
	&reset_environment();
	}
else {
	&error("Don't know how to install package $pkg->{'name'} with type $pkg->{'type'}");
	}
# Flush installed cache
unlink($current_cache_file);
return @rv;
}

# package_install_multiple(&package-names, system, [new-install])
# Install multiple packages, either from an update system or from Webmin.
# Returns a list of updated package names.
sub package_install_multiple
{
my ($names, $system, $install) = @_;
my @rv;
my $pkg;

if (defined(&software::update_system_install)) {
	# Using some update system, like YUM or APT
	&clean_environment();
	if ($software::update_system eq $system) {
		# Can use the default system
		@rv = &software::update_system_install(
			join(" ", @$names), undef, 1);
		}
	else {
		# Another update system exists!! Use it..
		if (!$done_rhn_lib++) {
			do "../software/$pkg->{'system'}-lib.pl";
			}
		if (!$done_rhn_text++) {
			%text = ( %text, %software::text );
			}
		@rv = &update_system_install(join(" ", @$names), undef, 1);
		}
	&reset_environment();
	}
else {
	&error("Don't know how to install packages");
	}
# Flush installed cache
unlink($current_cache_file);
return @rv;
}

# list_package_operations(package|packages, system)
# Given a package (or space-separate package list), returns a list of all
# dependencies that will be installed
sub list_package_operations
{
my ($name, $system) = @_;
if (defined(&software::update_system_operations)) {
	my @rv = &software::update_system_operations($name);
	foreach my $p (@rv) {
		$p->{'system'} = $system;
		}
	return @rv;
	}
return ( );
}

# list_possible_updates([nocache])
# Returns a list of updates that are available. Each element in the array
# is a hash ref containing a name, version, description and severity flag.
# Intended for calling from themes. Nocache 0=cache everything, 1=flush all
# caches, 2=flush only current
sub list_possible_updates
{
my ($nocache) = @_;
my @rv;
my @current = &list_current($nocache);
if (&supports_updates_available()) {
	# Software module supplies a function that can list just packages
	# that need updating
	my %currentmap;
	foreach my $c (@current) {
		$currentmap{$c->{'name'},$c->{'system'}} ||= $c;
		}
	foreach my $a (&updates_available($nocache == 1)) {
		my $c = $currentmap{$a->{'name'},$a->{'system'}};
		next if (!$c);
		next if ($a->{'version'} eq $c->{'version'});
		push(@rv, { 'name' => $a->{'name'},
			    'update' => $a->{'update'},
			    'system' => $a->{'system'},
			    'version' => $a->{'version'},
			    'oldversion' => $c->{'version'},
			    'epoch' => $a->{'epoch'},
			    'oldepoch' => $c->{'epoch'},
			    'security' => $a->{'security'},
			    'source' => $a->{'source'},
			    'desc' => $c->{'desc'} || $a->{'desc'} });
		}
	}
else {
	# Compute from current and available list
	my @avail = &list_available($nocache == 1);
	my %availmap;
	foreach my $a (@avail) {
		my $oa = $availmap{$a->{'name'},$a->{'system'}};
		if (!$oa || &compare_versions($a, $oa) > 0) {
			$availmap{$a->{'name'},$a->{'system'}} = $a;
			}
		}
	foreach my $c (sort { $a->{'name'} cmp $b->{'name'} } @current) {
		# Work out the status
		my $a = $availmap{$c->{'name'},$c->{'system'}};
		if ($a->{'version'} && &compare_versions($a, $c) > 0) {
			# A regular update is available
			push(@rv, { 'name' => $a->{'name'},
				    'update' => $a->{'update'},
				    'system' => $a->{'system'},
				    'version' => $a->{'version'},
				    'oldversion' => $c->{'version'},
				    'epoch' => $a->{'epoch'},
				    'oldepoch' => $c->{'epoch'},
				    'security' => $a->{'security'},
				    'source' => $a->{'source'},
				    'desc' => $c->{'desc'} || $a->{'desc'},
				    'severity' => 0 });
			}
		}
	}
@rv = &filter_duplicates(\@rv);
return @rv;
}

# list_possible_installs([nocache])
# Returns a list of packages that could be installed, but are not yet
sub list_possible_installs
{
my ($nocache) = @_;
my @rv;
my @current = &list_current($nocache);
my @avail = &list_available($nocache == 1);
foreach my $a (sort { $a->{'name'} cmp $b->{'name'} } @avail) {
	($c) = grep { $_->{'name'} eq $a->{'name'} &&
		      $_->{'system'} eq $a->{'system'} } @current;
	if (!$c && &installation_candiate($a)) {
		push(@rv, { 'name' => $a->{'name'},
			    'update' => $a->{'update'},
			    'system' => $a->{'system'},
			    'version' => $a->{'version'},
			    'epoch' => $a->{'epoch'},
			    'desc' => $a->{'desc'},
			    'severity' => 0 });
		}
	}
return @rv;
}

# csw_to_pkgadd(package)
# On Solaris systems, convert a CSW package name like ap2_modphp5 to a
# real package name like CSWap2modphp5
sub csw_to_pkgadd
{
my ($pn) = @_;
if ($gconfig{'os_type'} eq 'solaris') {
	$pn =~ s/[_\-]//g;
	$pn = "CSW$pn";
	}
return $pn;
}

# fix_pkgadd_version(&package)
# If this is Solaris and the package version is missing, we need to make 
# a separate pkginfo call to get it.
sub fix_pkgadd_version
{
my ($pkg) = @_;
if ($gconfig{'os_type'} eq 'solaris') {
	if (!$pkg->{'version'}) {
		# Make an extra call to get the version
		my @pinfo = &software::package_info($pkg->{'name'});
		$pinfo[4] =~ s/,REV=.*//i;
		$pkg->{'version'} = $pinfo[4];
		}
	else {
		# Trip off the REV=
		$pkg->{'version'} =~ s/,REV=.*//i;
		}
	}
$pkg->{'desc'} =~ s/^\Q$pkg->{'update'}\E\s+\-\s+//;
}

# installation_candiate(&package)
# Returns 1 if some package can be installed, even when it currently isn't.
# Always true for now.
sub installation_candiate
{
my ($p) = @_;
return 1;
}

# clear_repository_cache()
# Clear any YUM or APT caches
sub clear_repository_cache
{
if ($software::update_system eq "yum") {
	&execute_command("$software::yum_command clean all");
	}
elsif ($software::update_system eq "apt") {
	&execute_command("apt-get update");
	}
elsif ($software::update_system eq "ports") {
	&foreign_require("proc");
	foreach my $cmd ("portsnap fetch",
			 "portsnap update || portsnap extract") {
		my ($fh, $pid) = &proc::pty_process_exec($cmd);
		while(<$fh>) { }
		close($fh);
		}
	}
}

# split_epoch(version)
# Splits a version formatted like 5:x.yy into an epoch and real version
sub split_epoch
{
my ($ver) = @_;
if ($ver =~ /^(\d+):(\S+)$/) {
	return ($1, $2);
	}
return (undef, $ver);
}

# get_changelog(&pacakge)
# If possible, returns information about what has changed in some update
sub get_changelog
{
my ($pkg) = @_;
if ($pkg->{'system'} eq 'yum') {
	# See if yum supports changelog
	if (!defined($supports_yum_changelog)) {
		my $out = &backquote_command("$software::yum_command -h 2>&1 </dev/null");
		$supports_yum_changelog = $out =~ /changelog|updateinfo/ ? 1 : 0;
		}
	return undef if (!$supports_yum_changelog);

	# Check if we have this info cached
	my $cfile = $yum_changelog_cache_dir."/".
		       $pkg->{'name'}."-".$pkg->{'version'};
	my $cl = &read_file_contents($cfile);
	if (!$cl && $software::yum_command =~ /yum/) {
		# Run yum changelog for this package and version
		my $started = 0;
		&open_execute_command(YUMCL,
			"$software::yum_command changelog all ".
		        quotemeta($pkg->{'name'}), 1, 1);
                while(<YUMCL>) {
                        s/\r|\n//g;
                        if (/^\Q$pkg->{'name'}-$pkg->{'version'}\E/) {
                                $started = 1;
                                }
                        elsif (/^==========/ || /^changelog stats/) {
                                $started = 0;
                                }
                        elsif ($started) {
                                $cl .= $_."\n";
                                }
                        }
                close(YUMCL);
		}
	elsif (!$cl && $software::yum_command =~ /dnf/) {
		# Run dnf updateinfo for this package and version
		&open_execute_command(DNFUI,
			"$software::yum_command updateinfo info ".
		        quotemeta($pkg->{'name'}), 1, 1);
		while(<DNFUI>) {
			s/\r|\n//g;
			if (/^\s*Description\s*:\s*(.*)/) {
				$started = 1;
				$cl .= $1."\n";
				}
			elsif ($started && /^\s*:\s*(.*)/) {
				$cl .= $1."\n";
				}
			else {
				$started = 0;
				}
			}
		close(DNFUI);
		}
	if ($cl) {
		# Save the cache
		if (!-d $yum_changelog_cache_dir) {
			&make_dir($yum_changelog_cache_dir, 0700);
			}
		&open_tempfile(CACHE, ">$cfile");
		&print_tempfile(CACHE, $cl);
		&close_tempfile(CACHE);
		}
	return $cl;
	}
return undef;
}

sub flush_package_caches
{
unlink($current_cache_file);
unlink($updates_cache_file);
unlink($available_cache_file);
unlink($available_cache_file.'0');
unlink($available_cache_file.'1');
@packages_available_cache = ( );
%read_cache_file_cache = ( );
}

# list_for_mode(mode, nocache)
# If not is 'updates' or 'security', return just updates. Othewise, return
# all available packages.
sub list_for_mode
{
my ($mode, $nocache) = @_;
return $mode eq 'updates' || $mode eq 'security' ?
	&list_possible_updates($nocache) : &list_available($nocache);
}

# check_reboot_required(after-flag)
# Returns 1 if the package system thinks a reboot is needed
sub check_reboot_required
{
if ($gconfig{'os_type'} eq 'debian-linux') {
        return -e "/var/run/reboot-required" ? 1 : 0;
        }
return 0;
}

# start_update_progress(&packages)
# Record that a bunch of package updates are in progress by this process
sub start_update_progress
{
my ($pkgs) = @_;
if (!-d $update_progress_dir) {
	&make_dir($update_progress_dir, 0700);
	}
my $f = "$update_progress_dir/$$";
&write_file($f, { 'pid' => $$,
		  'pkgs' => join(' ', @$pkgs) });
}

# end_update_progress()
# Clear update progress marker file
sub end_update_progress
{
my $f = "$update_progress_dir/$$";
&unlink_file($f);
}

# get_update_progress()
# Returns a list of hash refs, one per update in progress
sub get_update_progress
{
my @rv;
foreach my $f (glob("$update_progress_dir/*")) {
	my %u;
	&read_file($f, \%u) || next;
	$u{'pid'} || next;
	kill(0, $u{'pid'}) || next;
	push(@rv, \%u);
	}
return @rv;
}

1;

