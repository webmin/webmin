# Functions for checking for updates to packages from YUM, APT or some other
# update system.
#
# XXX don't show virtualmin-specific mode ever
# XXX offer to install packages?
# XXX cron job to collect .. actually use webmin module collector
# XXX confirmation form, showing all dependencies
# XXX call yum info to get full package list, from software module

BEGIN { push(@INC, ".."); };
eval "use WebminCore;";
&init_config();
&foreign_require("software", "software-lib.pl");
&foreign_require("cron", "cron-lib.pl");
&foreign_require("webmin", "webmin-lib.pl");
use Data::Dumper;

@update_packages = ( "apache", "postfix", "sendmail", "bind", "procmail",
		     "spamassassin", "logrotate", "webalizer", "mysql",
		     "postgresql", "proftpd", "clamav", "php4", "mailman",
		     "subversion", "python", "ruby", "irb", "rdoc", "rubygems",
		     "openssl", "perl", "php5", "webmin", "usermin",
		     "fcgid", "awstats", "dovecot", "postgrey",
		     "virtualmin-modules",
		   ); 

$available_cache_file = "$module_config_directory/available.cache";
$current_cache_file = "$module_config_directory/current.cache";
$current_all_cache_file = "$module_config_directory/current-all.cache";
$cron_cmd = "$module_config_directory/update.pl";

$yum_cache_file = "$module_config_directory/yumcache";
$apt_cache_file = "$module_config_directory/aptcache";
$yum_changelog_cache_dir = "$module_config_directory/yumchangelog";

# list_current(nocache)
# Returns a list of packages and versions for the core packages managed
# by this module. Return keys are :
#  name - The local package name (ie. CSWapache2)
#  update - Name used to refer to it by the updates system (ie. apache2)
#  version - Version number
#  epoch - Epoch part of the version
#  desc - Human-readable description
#  package - Original generic program, like apache
sub list_current
{
local ($nocache) = @_;
if ($nocache || &cache_expired($current_cache_file)) {
	local $n = &software::list_packages();
	local @rv;
	foreach my $p (@update_packages) {
		local @pkgs = split(/\s+/, &package_resolve($p));
		foreach my $pn (@pkgs) {
			my $updatepn = $pn;
			$pn = &csw_to_pkgadd($pn);
			for(my $i=0; $i<$n; $i++) {
				next if ($software::packages{$i,'name'}
					 !~ /^$pn$/);
				push(@rv, {
				  'update' =>
				    $updatepn eq $pn ? 
					$software::packages{$i,'name'} :
					$updatepn,
				  'name' =>
				    $software::packages{$i,'name'},
				  'version' =>
				    $software::packages{$i,'version'},
				  'epoch' =>
				    $software::packages{$i,'epoch'},
				  'desc' =>
				    $software::packages{$i,'desc'},
				  'package' => $p,
				  'system' => $software::update_system,
				  'software' => 1,
				  });
				&fix_pkgadd_version($rv[$#rv]);
				}
			}
		}

	# Filter out dupes and sort by name
	@rv = &filter_duplicates(\@rv);

	local $incwebmin = &include_webmin_modules();
	if ($incwebmin) {
		# Add installed Webmin modules
		foreach my $minfo (&get_all_module_infos()) {
			push(@rv, { 'name' => $minfo->{'dir'},
				    'update' => $minfo->{'dir'},
				    'desc' => &text('index_webmin',
						    $minfo->{'desc'}),
				    'version' => $minfo->{'version'},
				    'system' => 'webmin',
				    'updateonly' => 1,
				  });
			}

		# Add installed Webmin themes
		foreach my $tinfo (&webmin::list_themes()) {
			push(@rv, { 'name' => $tinfo->{'dir'},
				    'update' => $tinfo->{'dir'},
				    'desc' => &text('index_webmintheme',
						    $tinfo->{'desc'}),
				    'version' => $tinfo->{'version'},
				    'system' => 'webmin',
				    'updateonly' => 1,
				  });
			}

		# Add an entry for Webmin itself, but only if this was
		# a tar.gz install
		if ($incwebmin != 2) {
			push(@rv, { 'name' => 'webmin',
				    'update' => 'webmin',
				    'desc' => 'Webmin Package',
				    'version' => &get_webmin_version(),
				    'system' => 'tgz',
				    'updateonly' => 1,
				  });
			}
		else {
			# Remove Webmin from the list, as YUM sometimes
			# includes it in the 'yum list' output even though
			# it cannot actual do an update!
			@rv = grep { $_->{'name'} ne 'webmin' } @rv;
			}

		# If Usermin is installed from a tgz, add it too
		if (&include_usermin_modules() == 1) {
			push(@rv, { 'name' => 'usermin',
				    'update' => 'usermin',
				    'desc' => 'Usermin Package',
				    'version' =>
					&usermin::get_usermin_version(),
				    'system' => 'tgz',
				    'updateonly' => 1,
				  });
			}
		else {
			@rv = grep { $_->{'name'} ne 'usermin' } @rv;
			}
		}

	&write_cache_file($current_cache_file, \@rv);
	return @rv;
	}
else {
	return &read_cache_file($current_cache_file);
	}
}

# list_all_current(nocache)
# Returns a list of all installed packages, in the same format as list_current
sub list_all_current
{
local ($nocache) = @_;
local ($nocache) = @_;
if ($nocache || &cache_expired($current_all_cache_file)) {
	local $n = &software::list_packages();
	local @rv;
	local %pkgmap;
	foreach my $p (@update_packages) {
		local @pkgs = split(/\s+/, &package_resolve($p));
		foreach my $pn (@pkgs) {
			$pkgmap{$pn} = $p;
			}
		}
	for(my $i=0; $i<$n; $i++) {
		push(@rv, { 'name' => $software::packages{$i,'name'},
			    'update' => $software::packages{$i,'name'},
			    'version' =>
			      $software::packages{$i,'version'},
			    'epoch' =>
			      $software::packages{$i,'epoch'},
			    'desc' =>
			      $software::packages{$i,'desc'},
			    'package' => $pkgmap{$software::packages{$i,'name'}},
			    'system' => $software::update_system,
			});
		&fix_pkgadd_version($rv[$#rv]);
		}

	# Filter out dupes and sort by name
	@rv = &filter_duplicates(\@rv);

	&write_cache_file($current_all_cache_file, \@rv);
	return @rv;
	}
else {
	return &read_cache_file($current_all_cache_file);
	}
}

# list_available(nocache, all)
# Returns the names and versions of packages available from the update
# system, that we are interested in.
sub list_available
{
local ($nocache, $all) = @_;
if ($nocache || &cache_expired($available_cache_file.int($all))) {
	# Get from update system
	local @rv;
	local @avail = &packages_available();
	if (!$all) {
		# Limit to packages Virtualmin cares about
		foreach my $p (@update_packages) {
			local @pkgs = split(/\s+/, &package_resolve($p));
			foreach my $pn (@pkgs) {
				local @mavail = grep { $_->{'name'} =~ /^$pn$/ }
						     @avail;
				foreach my $avail (@mavail) {
					$avail->{'update'} = $avail->{'name'};
					$avail->{'name'} =
					    &csw_to_pkgadd($avail->{'name'});
					$avail->{'package'} = $p;
					&set_pinned_version($avail);
					push(@rv, $avail);
					}
				}
			}
		}
	else {
		# All on system
		foreach my $avail (@avail) {
			$avail->{'update'} = $avail->{'name'};
			$avail->{'name'} = &csw_to_pkgadd($avail->{'name'});
			&set_pinned_version($avail);
			push(@rv, $avail);
			}
		}

	# Set descriptions if needed
	foreach my $avail (@rv) {
		if (&installation_candiate($avail)) {
			$avail->{'desc'} ||= &generate_description($avail);
			}
		}

	# Filter out dupes and sort by name
	@rv = &filter_duplicates(\@rv);

	if (!@rv) {
		# Failed .. fall back to cache
		@rv = &read_cache_file($available_cache_file.int($all));
		}
	&write_cache_file($available_cache_file.int($all), \@rv);
	return @rv;
	}
else {
	return &read_cache_file($available_cache_file.int($all));
	}
}

# filter_duplicates(&packages)
# Given a list of package structures, orders them by name and version number,
# and removes dupes with the same name
sub filter_duplicates
{
local ($pkgs) = @_;
local @rv = sort { $a->{'name'} cmp $b->{'name'} ||
	         &compare_versions($b, $a) } @$pkgs;
local %done;
return grep { !$done{$_->{'name'},$_->{'system'}}++ } @rv;
}

sub cache_expired
{
local ($file) = @_;
local @st = stat($file);
if (!@st || !$config{'cache_time'} ||
    time()-$st[9] > $config{'cache_time'}*60*60) {
	return 1;
	}
return 0;
}

sub write_cache_file
{
local ($file, $arr) = @_;
&open_tempfile(FILE, ">$file");
&print_tempfile(FILE, Dumper($arr));
&close_tempfile(FILE);
}

sub read_cache_file
{
local ($file) = @_;
local $dump = &read_file_contents($file);
return () if (!$dump);
my $arr = eval $dump;
return @$arr;
}

# compare_versions(&pkg1, &pk2)
# Returns -1 if the version of pkg1 is older than pkg2, 1 if newer, 0 if same.
sub compare_versions
{
local ($pkg1, $pkg2) = @_;
if ($pkg1->{'system'} eq 'webmin' && $pkg2->{'system'} eq 'webmin') {
	# Webmin module version compares are always numeric
	return $pkg1->{'version'} <=> $pkg2->{'version'};
	}
local $ec = $pkg1->{'epoch'} <=> $pkg2->{'epoch'};
if ($ec && ($pkg1->{'epoch'} eq '' || $pkg2->{'epoch'} eq '') &&
    $pkg1->{'system'} eq 'apt') {
	# On some Debian systems, we don't have a local epoch
	$ec = undef;
	}
return $ec ||
       &software::compare_versions($pkg1->{'version'}, $pkg2->{'version'});
}

sub find_cron_job
{
local @jobs = &cron::list_cron_jobs();
local ($job) = grep { $_->{'user'} eq 'root' &&
		      $_->{'command'} eq $cron_cmd } @jobs;
return $job;
}

# package_resolve(name)
# Given a package code name from @update_packages, returns a string of the
# underlying packages that implement it. This may come from the update system
# if the OS has one (YUM or APT, or from Virtualmin's built-in list)
sub package_resolve
{
local ($name) = @_;
local $realos = $gconfig{'real_os_type'};
$realos =~ s/ /-/g;
local $realver = $gconfig{'real_os_version'};
$realver =~ s/ /-/g;
if (open(RESOLV, "$module_root_directory/resolve.$realos-$realver") ||
    open(RESOLV, "$module_root_directory/resolve.$realos") ||
    open(RESOLV, "$module_root_directory/resolve.$gconfig{'os_type'}-$gconfig{'os_version'}") ||
    open(RESOLV, "$module_root_directory/resolve.$gconfig{'os_type'}")) {
	local $rv;
	while(<RESOLV>) {
		if (/^(\S+)\s+(.*)/ && $1 eq $name) {
			$rv = $2;
			}
		elsif (/^\*/) {
			# All other packages have the same name as their code
			$rv = $name;
			}
		}
	close(RESOLV);
	return $rv if ($rv);
	}
if (defined(&software::update_system_resolve)) {
	return &software::update_system_resolve($name);
	}
return $name;
}

# packages_available()
# Returns a list of all available packages, as hash references with name and
# version keys. These come from the APT, YUM or CSW update system, if available.
# If not, nothing is returned.
sub packages_available
{
if (defined(&software::update_system_available)) {
	# From a decent package system
	local @rv = software::update_system_available();
	local %done;
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
		local @rhnrv = &update_system_available();
		foreach my $p (@rhnrv) {
			$p->{'system'} = "rhn";
			local $d = $done{$p->{'name'}};
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
	return @rv;
	}
return ( );
}

# package_install(package, [system], [check-all])
# Install some package, either from an update system or from Webmin. Returns
# a list of updated package names.
sub package_install
{
local ($name, $system, $all) = @_;
local @rv;
local ($pkg) = grep { $_->{'update'} eq $name &&
		      ($_->{'system'} eq $system || !$system) }
		    sort { &compare_versions($b, $a) }
		         &list_available(0, $all);
if (!$pkg) {
	print &text('update_efindpkg', $name),"<p>\n";
	return ( );
	}
if ($pkg->{'system'} eq 'webmin') {
	# Webmin module, which we can download and install 
	local ($host, $port, $page, $ssh) =
		&parse_http_url($pkg->{'updatesurl'});
	local ($mhost, $mport, $mpage, $mssl) =
		&parse_http_url($pkg->{'url'}, $host, $port, $page, $ssl);
	local $mfile;
	($mfile = $mpage) =~ s/^(.*)\///;
	local $mtemp = &transname($mfile);
	local $error;
	print &text('update_wdownload', $pkg->{'name'}),"<br>\n";
	&http_download($mhost, $mport, $mpage, $mtemp, \$error, undef, $mssl,
		       $webmin::config{'upuser'}, $webmin::config{'uppass'});
	if ($error) {
		print &text('update_ewdownload', $error),"<p>\n";
		return ( );
		}
	print $text{'update_wdownloaded'},"<p>\n";

	# Install the module
	print &text('update_winstall', $pkg->{'name'}),"<br>\n";
	local $irv = &webmin::install_webmin_module($mtemp, 1, 0);
	if (!ref($irv)) {
		print &text('update_ewinstall', $irv),"<p>\n";
		}
	else {
		print $text{'update_winstalled'},"<p>\n";
		@rv = map { /([^\/]+)$/; $1 } @{$irv->[1]};
		}
	}
elsif (defined(&software::update_system_install)) {
	# Using some update system, like YUM or APT
	&clean_environment();
	if ($software::update_system eq $pkg->{'system'}) {
		# Can use the default system
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
unlink($current_all_cache_file);
return @rv;
}

# list_possible_updates([nocache])
# Returns a list of updates that are available. Each element in the array
# is a hash ref containing a name, version, description and severity flag.
# Intended for calling from themes. Nocache 0=cache everything, 1=flush all
# caches, 2=flush only current
sub list_possible_updates
{
local ($nocache) = @_;
local @rv;
local @current = &list_current($nocache);
local @avail = &list_available($nocache == 1);
@avail = sort { &compare_versions($b, $a) } @avail;
local ($a, $c, $u);
foreach $c (sort { $a->{'name'} cmp $b->{'name'} } @current) {
	# Work out the status
	($a) = grep { $_->{'name'} eq $c->{'name'} &&
		      $_->{'system'} eq $c->{'system'} } @avail;
	if ($a->{'version'} && &compare_versions($a, $c) > 0) {
		# A regular update is available
		push(@rv, { 'name' => $a->{'name'},
			    'update' => $a->{'update'},
			    'system' => $a->{'system'},
			    'version' => $a->{'version'},
			    'epoch' => $a->{'epoch'},
			    'desc' => $c->{'desc'} || $a->{'desc'},
			    'severity' => 0 });
		}
	}
return @rv;
}

# list_possible_installs([nocache])
# Returns a list of packages that could be installed, but are not yet
sub list_possible_installs
{
local ($nocache) = @_;
local @rv;
local @current = &list_current($nocache);
local @avail = &list_available($nocache == 1);
local ($a, $c);
foreach $a (sort { $a->{'name'} cmp $b->{'name'} } @avail) {
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
local ($pn) = @_;
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
local ($pkg) = @_;
if ($gconfig{'os_type'} eq 'solaris') {
	if (!$pkg->{'version'}) {
		# Make an extra call to get the version
		local @pinfo = &software::package_info($pkg->{'name'});
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

# include_webmin_modules()
# Returns 1 if we should include all Webmin modules and the program itself in
# the list of updates. Returns 2 if only non-core modules should be included.
# The first case is selected when you have a tar.gz install, while the second
# corresponds to a rpm or deb install with Virtualmin modules added.
sub include_webmin_modules
{
return 0 if (&webmin::shared_root_directory());
local $type = &read_file_contents("$root_directory/install-type");
chop($type);
if (!$type) {
	# Webmin tar.gz install
	return 1;
	}
else {
	# How was virtual-server installed?
	return 0 if (!&foreign_check("virtual-server"));
	local $vtype = &read_file_contents(
		&module_root_directory("virtual-server")."/install-type");
	chop($vtype);
	if (!$vtype) {
		# A tar.gz install ... which we may be able to update
		return 2;
		}
	return 0;
	}
}

# include_usermin_modules()
# Returns 1 if Usermin was installed from a tar.gz, 2 if installed from an
# RPM but virtualmin-specific modules were from a tar.gz
sub include_usermin_modules
{
if (&foreign_installed("usermin")) {
	&foreign_require("usermin", "usermin-lib.pl");
	local $type = &usermin::get_install_type();
	if (!$type) {
		# Usermin tar.gz install
		return 1;
		}
	else {
		# How was virtual-server-theme installed?
		local %miniserv;
		&usermin::get_usermin_miniserv_config(\%miniserv);
		local $vtype = &read_file_contents(
			"$miniserv{'root'}/virtual-server-theme/install-type");
		chop($vtype);
		if (!$vtype) {
			# A tar.gz install ... which we may be able to update
			return 2;
			}
		return 0;
		}
	}
return 0;
}

# installation_candiate(&package)
# Returns 1 if some package can be installed, even when it currently isn't.
# Always true for now.
sub installation_candiate
{
local ($p) = @_;
return 1;
}

# generate_description(package)
# Fakes up a description for a Webmin/Usermin module/theme package
sub generate_description
{
local ($p) = @_;
local $name = $p->{'name'};
if ($p->{'system'} eq 'yum') {
	# Use yum info to get the description, and cache it
	local %yumcache;
	&read_file_cached($yum_cache_file, \%yumcache);
	if ($yumcache{$p->{'name'}."-".$p->{'version'}}) {
		return $yumcache{$p->{'name'}."-".$p->{'version'}};
		}
	local ($desc, $started_desc);
	open(YUM, "yum info ".quotemeta($name)." |");
	while(<YUM>) {
		s/\r|\n//g;
		if (/^Description:\s*(.*)$/) {
			$desc = $1;
			$started_desc = 1;
			}
		elsif (/\S/ && $started_desc) {
			$desc .= " ".$_;
			}
		}
	close(YUM);
	$desc =~ s/^\s+//;
	$yumcache{$p->{'name'}."-".$p->{'version'}} = $desc;
	&write_file($yum_cache_file, \%yumcache);
	return $desc if ($desc =~ /\S/);
	}
elsif ($p->{'system'} eq 'apt') {
	# Use APT to get description
	local %aptcache;
	&read_file_cached($apt_cache_file, \%aptcache);
	if ($aptcache{$p->{'name'}."-".$p->{'version'}}) {
		return $aptcache{$p->{'name'}."-".$p->{'version'}};
		}
	local ($desc, $started_desc);
	open(YUM, "apt-cache show ".quotemeta($name)." |");
	while(<YUM>) {
		s/\r|\n//g;
		if (/^Description:\s*(.*)$/) {
			$desc = $1;
			}
		}
	close(YUM);
	$aptcache{$p->{'name'}."-".$p->{'version'}} = $desc;
	&write_file($apt_cache_file, \%aptcache);
	return $desc if ($desc =~ /\S/);
	}

return # RPM names
       $name =~ /^wbm-virtualmin-/ ? "Virtualmin plugin" :
       $name =~ /^wbm-vm2-/ ? "Cloudmin plugin" :
       $name =~ /^wbm-/ ? "Webmin module" :
       $name =~ /^wbt-virtualmin-/ ? "Virtualmin theme" :
       $name =~ /^wbt-/ ? "Webmin theme" :
       $name =~ /^usm-/ ? "Usermin module" :
       $name =~ /^ust-/ ? "Usermin theme" :

       # Debian names
       $name =~ /^webmin-virtualmin-/ ? "Virtualmin plugin or theme" :
       $name =~ /^webmin-vm2-/ ? "Cloudmin plugin" :
       $name =~ /^webmin-/ ? "Webmin module" :
       $name =~ /^usermin-virtualmin-/ ? "Usermin theme" :
       $name =~ /^usermin-/ ? "Usermin module" :

       undef;
}

# clear_repository_cache()
# Clear any YUM or APT caches
sub clear_repository_cache
{
if ($software::update_system eq "yum") {
	&execute_command("yum clean all");
	}
elsif ($software::update_system eq "apt") {
	&execute_command("apt-get update");
	}
}

# set_pinned_version(&package)
# Given an APT package from the available, use apt-cache policy to check if it
# should have the version number reduced to the pinned version.
sub set_pinned_version
{
local ($pkg) = @_;
return 0 if ($pkg->{'system'} ne 'apt');
local $rv = 0;
local $qp = quotemeta($pkg->{'name'});
local $out = &backquote_command("LANG='' LC_ALL='' apt-cache policy $qp 2>/dev/null");
local $installed = $out =~ /Installed:\s+(\S+)/ ? $1 : undef;
local $candidate = $out =~ /Candidate:\s+(\S+)/ ? $1 : undef;
$candidate = "" if ($candidate eq "(none)");
if ($installed && $candidate) {
	# An installation candidate is defined .. use it
	local $cepoch;
	if ($candidate =~ s/^(\d+)://) {
		$cepoch = $1;
		}
	if ($pkg->{'version'} ne $candidate) {
		$pkg->{'version'} = $candidate;
		$pkg->{'epoch'} = $cepoch;
		}
	$rv = 1;
	}
if ($installed && $candidate &&
    $gconfig{'os_type'} eq 'debian-linux' && $gconfig{'os_version'} eq '4.0') {
	# Don't offer to upgrade to Lenny packages .. first work out which
	# versions apt-get knows about.
	local @lines = split(/\r?\n/, $out);
	local $found_versions;
	local @versions;
	for(my $i=0; $i<@lines; $i++) {
		if ($lines[$i] =~ /\s*Version\s+table:/i) {
			$found_versions = 1;
			next;
			}
		next if (!$found_versions);
		if ($lines[$i] =~ /^[ \*]+(\S+)/) {
			# Found a version number
			local $ver = $1;
			$i++;
			if ($lines[$i] =~ /^\s+(\d+)\s+(\S.*)$/) {
				push(@versions, { 'version' => $ver,
						  'pri' => $1,
						  'url' => $2 });
				}
			}
		}
	# If the latest version is from stable, don't use it
	@versions = sort { &compare_versions($b, $a) } @versions;
	local ($nv) = grep { $_->{'version'} eq $pkg->{'version'} ||
			     $_->{'version'} eq $pkg->{'epoch'}.':'.
					     $pkg->{'version'} } @versions;
	if ($nv && $nv->{'url'} =~ /stable/ && $nv->{'url'} !~ /virtualmin/) {
		shift(@versions);
		local $safever = @versions ? $versions[0]->{'version'}
					   : $installed;
		local $sepoch;
		if ($safever =~ s/^(\d+)://) {
			$sepoch = $1;
			}
		$pkg->{'version'} = $safever;
		$pkg->{'epoch'} = $sepoch;
		}
	}
return $rv;
}

# get_changelog(&pacakge)
# If possible, returns information about what has changed in some update
sub get_changelog
{
local ($pkg) = @_;
if ($pkg->{'system'} eq 'yum') {
	# See if yum supports changelog
	if (!defined($supports_yum_changelog)) {
		local $out = &backquote_command("yum -h 2>&1 </dev/null");
		$supports_yum_changelog = $out =~ /changelog/ ? 1 : 0;
		}
	return undef if (!$supports_yum_changelog);

	# Check if we have this info cached
	local $cfile = $yum_changelog_cache_dir."/".
		       $pkg->{'name'}."-".$pkg->{'version'};
	local $cl = &read_file_contents($cfile);
	if (!$cl) {
		# Run it for this package and version
		local $started = 0;
		&open_execute_command(YUMCL, "yum changelog all ".
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

# Returns 1 if an option should be shown to list all packages. Only true for
# YUM and APT at the moment
sub show_all_option
{
return $software::update_system eq 'apt' || $software::update_system eq 'yum';
}

sub flush_package_caches
{
unlink($current_cache_file);
unlink($current_all_cache_file);
unlink($updates_cache_file);
unlink($available_cache_file);
unlink($available_cache_file.'0');
unlink($available_cache_file.'1');
}

1;

