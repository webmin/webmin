# cpan-lib.pl
# Functions for getting information about perl modules

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
use Config;

$packages_file = "$module_config_directory/packages.txt.gz";
if (!-r $packages_file) {
	$packages_file = "$module_var_directory/packages.txt.gz";
	}
$available_packages_cache = "$module_config_directory/available-cache";
if (!-r $available_packages_cache) {
	$available_packages_cache = "$module_var_directory/available-cache";
	}

# Get the paths to perl and perldoc
$perl_path = &get_perl_path();
if (&has_command("perldoc")) {
	$perl_doc = &has_command("perldoc");
	}
else {
	$perl_path =~ /^(.*)\/[^\/]+$/;
	if (-x "$1/perldoc") {
		$perl_doc = "$1/perldoc";
		}
	}
if ($perl_doc && $] >= 5.006) {
	$perl_doc = "$perl_path -T $perl_doc";
	}

# list_perl_modules([master-name])
# Returns a list of all installed perl modules, by reading .packlist files
sub list_perl_modules
{
local ($limit) = @_;
local (@rv, %done, $d, %donedir, %donemod);
foreach $d (&expand_usr64($Config{'privlib'}),
	    &expand_usr64($Config{'sitelib_stem'} ? $Config{'sitelib_stem'} :
				      		    $Config{'sitelib'}),
	    &expand_usr64($Config{'sitearch_stem'} ? $Config{'sitearch_stem'} :
				      		    $Config{'sitearch'}),
	    &expand_usr64($Config{'vendorlib_stem'} ? $Config{'vendorlib_stem'} :
				        	      $Config{'vendorlib'}),
	    &expand_usr64($Config{'installprivlib'})) {
	next if (!$d);
	next if ($donedir{$d});
	local $f;
	open(FIND, "find ".quotemeta($d)." -name .packlist -print |");
	while($f = <FIND>) {
		chop($f);
		local @st = stat($f);
		next if ($done{$st[0],$st[1]}++);
		local @st = stat($f);
		local $mod = { 'date' => scalar(localtime($st[9])),
			       'time' => $st[9],
			       'packfile' => $f,
			       'index' => scalar(@rv) };
		$f =~ /\/(([A-Z][^\/]*\/)*[^\/]+)\/.packlist$/;
		$mod->{'name'} = $1;
		$mod->{'name'} =~ s/\//::/g;
		next if ($limit && $mod->{'name'} ne $limit);
		next if ($donemod{$mod->{'name'}}++);

		# Add the files in the .packlist
		local (%donefile, $l);
		open(FILE, $f);
		while($l = <FILE>) {
			chop($l);
			$l =~ s/^\/tmp\/[^\/]+//;
			$l =~ s/^\/var\/tmp\/[^\/]+//;
			next if ($donefile{$l}++);
			if ($l =~ /\/((([A-Z][^\/]*\/)([^\/]+\/)?)?[^\/]+)\.pm$/) {
				local $mn = $1;
				$mn =~ s/\//::/g;
				push(@{$mod->{'mods'}}, $mn);
				push(@{$mod->{'files'}}, $l);
				}
			elsif ($l =~ /^([^\/]+)\.pm$/) {
				# Module name only, with no path! Damn redhat..
				local @rpath;
				open(FIND2, "find ".quotemeta($d).
					    " -name '$l' -print |");
				while(<FIND2>) {
					chop;
					push(@rpath, $_);
					}
				close(FIND2);
				@rpath = sort { length($a) cmp length($b) } @rpath;
				if (@rpath) {
					$rpath[0] =~ /\/(([A-Z][^\/]*\/)*[^\/]+)\.pm$/;
					local $mn = $1;
					$mn =~ s/\//::/g;
					push(@{$mod->{'mods'}}, $mn);
					push(@{$mod->{'files'}}, $rpath[0]);
					$mod->{'noremove'} = 1;
					$mod->{'noupgrade'} = 1;
					}
				}
			push(@{$mod->{'packlist'}}, $l);
			}
		close(FILE);
		local $mi = &indexof($mod->{'name'}, @{$mod->{'mods'}});
		$mod->{'master'} = $mi < 0 ? 0 : $mi;
		push(@rv, $mod) if (@{$mod->{'mods'}});
		}
	close(FIND);
	}

# Look for RPMs or Debs for Perl modules
if (&foreign_check("software") && $config{'incpackages'}) {
	&foreign_require("software", "software-lib.pl");
	if ($software::config{'package_system'} eq "rpm") {
		local $n = &software::list_packages();
		local $i;
		for($i=0; $i<$n; $i++) {
			# Create the module object
			next if ($software::packages{$i,'name'} !~
				 /^perl-([A-Z].*)$/ &&
				 $software::packages{$i,'name'} !~
				 /^([A-Z].*)-[pP]erl$/i);
			local $mod = { 'index' => scalar(@rv),
				       'pkg' => $software::packages{$i,'name'},
				       'pkgtype' => 'rpm',
				       'noupgrade' => 1,
				       'version' =>
					  $software::packages{$i,'version'} };
			$mod->{'name'} = $1;
			$mod->{'name'} =~ s/\-/::/g;
			next if ($limit && $mod->{'name'} ne $limit);
			next if ($donemod{$mod->{'name'}}++);

			# Add the files in the RPM
			# XXX call rpm -ql only, avoid -V step
			# XXX same for Debian
			# XXX list_package_files function, returns an array
			foreach my $l (&software::package_files(
					$software::packages{$i,'name'},
					$software::packages{$i,'version'})) {
				if ($l =~ /\/((([A-Z][^\/]*\/)([^\/]+\/)?)?[^\/]+)\.pm$/) {
					local $mn = $1;
					$mn =~ s/\//::/g;
					push(@{$mod->{'mods'}}, $mn);
					push(@{$mod->{'files'}}, $l);
					}
				push(@{$mod->{'packlist'}}, $l);
				if (!$mod->{'date'}) {
					local @st = stat($l);
					$mod->{'date'} = scalar(localtime($st[9]));
					$mod->{'time'} = $st[9];
					}
				}

			local $mi = &indexof($mod->{'name'}, @{$mod->{'mods'}});
			$mod->{'master'} = $mi < 0 ? 0 : $mi;
			push(@rv, $mod) if (@{$mod->{'mods'}});
			}
		}
	elsif ($software::config{'package_system'} eq "debian") {
		# Look for Debian packages of Perl modules
		local $n = &software::list_packages();
		local $i;
		for($i=0; $i<$n; $i++) {
			# Create the module object
			next if ($software::packages{$i,'name'} !~
				 /^lib(\S+)-perl$/);
			local $mod = { 'index' => scalar(@rv),
				       'pkg' => $software::packages{$i,'name'},
				       'pkgtype' => 'debian',
				       'noupgrade' => 1,
				       'version' =>
					  $software::packages{$i,'version'} };

			# Add the files in the RPM
			foreach my $l (&software::package_files(
					$software::packages{$i,'name'})) {
				if ($l =~ /\/((([A-Z][^\/]*\/)([^\/]+\/)?)?[^\/]+)\.pm$/) {
					local $mn = $1;
					$mn =~ s/\//::/g;
					push(@{$mod->{'mods'}}, $mn);
					push(@{$mod->{'files'}}, $l);
					}
				push(@{$mod->{'packlist'}}, $l);
				if (!$mod->{'date'}) {
					local @st = stat($l);
					$mod->{'date'} = scalar(localtime($st[9]));
					$mod->{'time'} = $st[9];
					}
				}
			next if (!@{$mod->{'mods'}});

			# Work out the name
			foreach my $m (@{$mod->{'mods'}}) {
				local $pn = lc($m);
				$pn =~ s/::/-/g;
				$pn = "lib".$pn."-perl";
				if ($pn eq $mod->{'pkg'}) {
					$mod->{'name'} = $m;
					last;
					}
				}
			$mod->{'name'} ||= $mod->{'mods'}->[0];
			next if ($limit && $mod->{'name'} ne $limit);
			next if ($donemod{$mod->{'name'}}++);

			local $mi = &indexof($mod->{'name'}, @{$mod->{'mods'}});
			$mod->{'master'} = $mi < 0 ? 0 : $mi;
			push(@rv, $mod) if (@{$mod->{'mods'}});
			}

		}
	}

return @rv;
}

# expand_usr64(dir)
# If a directory is like /usr/lib and /usr/lib64 exists, return them both
sub expand_usr64
{
if ($_[0] =~ /^(\/usr\/lib\/|\/usr\/local\/lib\/)(.*)$/) {
	local ($dir, $dir64, $rest) = ($1, $1, $2);
	$dir64 =~ s/\/lib\//\/lib64\//;
	return -d $dir64 ? ( $dir.$rest, $dir64.$rest ) : ( $dir.$rest );
	}
else {
	return ( $_[0] );
	}
}

# module_desc(&mod, index)
# Returns a one-line description for some module, and a version number
sub module_desc
{
local ($in_name, $desc);
local $f = $_[0]->{'files'}->[$_[1]];
local $pf = $f;
local $ver = $_[0]->{'version'};
$pf =~ s/\.pm$/\.pod/;
local ($got_version, $got_name);
open(MOD, $pf) || open(MOD, $f);
while(<MOD>) {
	if (/^=head1\s+name/i && !$got_name) {
		$in_name = 1;
		}
	elsif (/^=/ && $in_name) {
		$got_name++;
		$in_name = 0;
		}
	elsif ($in_name) {
		$desc .= $_;
		}
	if (/^\s*(our\s+)?\$VERSION\s*=\s*"([0-9\.]+)"/ ||
	    /^\s*(our\s+)?\$VERSION\s*=\s*'([0-9\.]+)'/ ||
	    /^\s*(our\s+)?\$VERSION\s*=\s*([0-9\.]+)/) {
		$ver = $2;
		$got_version++;
		}
	last if ($got_version && $got_name);
	}
close(MOD);
local $name = $_[0]->{'mods'}->[$_[1]];
$desc =~ s/^\s*$name\s+\-\s+// ||
	$desc =~ s/^\s*\S*<$name>\s+\-\s+//;
$desc =~ s/\$Id:.*\$//;
return wantarray ? ($desc, $ver) : $desc;
}

# download_packages_file(&callback)
sub download_packages_file
{
$config{'packages'} =~ /^http:\/\/([^\/]+)(\/.*)$/ ||
	&error($text{'download_epackages'});
local ($host, $page, $port) = ($1, $2, 80);
if ($host =~ /^(.*):(\d+)$/) { $host = $1; $port = $2; }
&http_download($host, $port, $page, $packages_file, undef, $_[0]);
}

# remove_module(&module)
# Delete some perl module, and all sub-modules
sub remove_module
{
local ($mod) = @_;
if ($mod->{'pkg'}) {
	&foreign_require("software", "software-lib.pl");
	return &software::delete_package($mod->{'pkg'});
	}
else {
	unlink(@{$mod->{'packlist'}});
	unlink($mod->{'packfile'});
	return undef;
	}
}

# get_recommended_modules()
# Returns a list of Perl modules used by other Webmin modules
sub get_recommended_modules
{
local (@rv, %done);
foreach my $m (&get_all_module_infos()) {
	next if (!$m->{'cpan'});
	next if (!&foreign_installed($m->{'dir'}));
	local $mdir = &module_root_directory($m->{'dir'});
	next if (!-r "$mdir/cpan_modules.pl");
	&foreign_require($m->{'dir'}, "cpan_modules.pl");
	foreach my $c (&foreign_call($m->{'dir'}, "cpan_recommended")) {
		if (!$done{$c}++) {
			push(@rv, [ $c, $m ]);
			}
		}
	}
return sort { $a->[0] cmp $b->[0] } @rv;
}

# can_list_packaged_modules()
# Returns 1 if we can install Perl modules from APT or YUM
sub can_list_packaged_modules
{
return 0 if (!&foreign_check("software") || !$config{'incpackages'});
&foreign_require("software", "software-lib.pl");
return 0 if (!$software::update_system);
return 1;
}

# list_packaged_modules([refresh])
# Returns a list of Perl modules that can be installed from the system's
# package update service (ie YUM or APT).
sub list_packaged_modules
{
local ($refresh) = @_;
return ( ) if (!&foreign_check("software") || !$config{'incpackages'});
&foreign_require("software", "software-lib.pl");
return (  ) if (!$software::update_system);
local @avail;
local @st = stat($available_packages_cache);
if ($refresh || !@st || $st[9] < time()-24*60*60) {	# Keep cache for a day
	# Need to refresh
	@avail = &software::update_system_available();
	open(CACHE, ">$available_packages_cache");
	print CACHE &serialise_variable(\@avail);
	close(CACHE);
	}
else {
	# Can use cache
	local $avail = &unserialise_variable(
			&read_file_contents($available_packages_cache));
	@avail = @$avail;
	}
local @rv;
foreach my $a (@avail) {
	if ($a->{'name'} =~ /^lib(\S+)-perl$/ ||	# Debian
	    $a->{'name'} =~ /^perl-(\S+)$/ ||		# Redhat
	    $a->{'name'} =~ /^p5-(\S+)$/) {		# FreeBSD
		local $mod = $1;
		$mod =~ s/-/::/g;
		if ($mod eq "LDAP") {
			# Special case for redhat-ish systems
			$mod = "Net::LDAP";
			}
		elsif ($mod eq "perl::ldap") {
			# Special case for FreeBSD
			$mod = "Net::LDAP";
			}
		push(@rv, { 'mod' => $mod,
			    'package' => $a->{'name'},
			    'version' => $a->{'version'}, });
		}
	}
return @rv;
}

# shared_perl_root()
# Returns 1 if Perl is shared with the root zone, indicating that Perl modules
# cannot be installed.
sub shared_perl_root
{
return 0 if (!&running_in_zone());
local $pp = &get_perl_path();
if (&foreign_exists("mount")) {
	&foreign_require("mount", "mount-lib.pl");
	local @rst = stat($pp);
	local $m;
	foreach $m (&mount::list_mounted()) {
		local @mst = stat($m->[0]);
		if ($mst[0] == $rst[0] &&
		    &is_under_directory($m->[0], $pp)) {
			# Found the mount!
			if ($m->[2] eq "lofs" || $m->[2] eq "nfs") {
				return 1;
				}
			}
		}
	}
return 0;
}

# get_nice_perl_version()
# Returns the Perl version is human-readable format
sub get_nice_perl_version
{
local $ver = $^V;
if ($ver =~ /^v/) {
	return $ver;
	}
else {
	return join(".", map { ord($_) } split(//, $^V));
	}
}

1;

