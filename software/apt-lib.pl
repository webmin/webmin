# apt-lib.pl
# Functions for installing packages from debian APT

$apt_get_command = $config{'apt_mode'} ? "aptitude" : "apt-get";
$apt_search_command = $config{'apt_mode'} ? "aptitude" : "apt-cache";

sub list_update_system_commands
{
return ($apt_get_command, $apt_search_command);
}

# update_system_install([package], [&in], [no-force])
# Install some package with apt
sub update_system_install
{
local $update = $_[0] || $in{'update'};
local $force = !$_[2];
local (@rv, @newpacks);

# Build the command to run
$ENV{'DEBIAN_FRONTEND'} = 'noninteractive';
local $cmd = "$apt_get_command -y ".($force ? " -f" : "")." install $update";
$update = join(" ", map { quotemeta($_) } split(/\s+/, $update));
print "<b>",&text('apt_install', "<tt>$cmd</tt>"),"</b><p>\n";
print "<pre>";
&additional_log('exec', undef, $cmd);

# Run dpkg --configure -a to clear any un-configured packages
$SIG{'TERM'} = 'ignore';	# This may cause a Webmin re-config!
local $out = &backquote_logged("dpkg --configure -a 2>&1 </dev/null");
print &html_escape($out);

# Create an input file of 'yes'
local $yesfile = &transname();
&open_tempfile(YESFILE, ">$yesfile", 0, 1);
foreach (0..100) {
	&print_tempfile(YESFILE, "Yes\n");
	}
&close_tempfile(YESFILE);

# Run the command
&open_execute_command(CMD, "$cmd <$yesfile", 2);
while(<CMD>) {
	if (/setting\s+up\s+(\S+)/i && !/as\s+MDA/i) {
		push(@rv, $1);
		}
	elsif (/packages\s+will\s+be\s+upgraded/i ||
	       /new\s+packages\s+will\s+be\s+installed/i) {
		print;
		$line = $_ = <CMD>;
		$line =~ s/^\s+//; $line =~ s/\s+$//;
		push(@newpacks, split(/\s+/, $line));
		}
	print &html_escape("$_");
	}
close(CMD);
if (!@rv && $config{'package_system'} ne 'debian' && !$?) {
	# Other systems don't list the packages installed!
	@rv = @newpacks;
	}
print "</pre>\n";
if ($?) { print "<b>$text{'apt_failed'}</b><p>\n"; }
else { print "<b>$text{'apt_ok'}</b><p>\n"; }
return @rv;
}

# update_system_operations(packages)
# Given a list of packages, returns a list containing packages that will
# actually get installed, each of which is a hash ref with name and version.
sub update_system_operations
{
my ($packages) = @_;
$ENV{'DEBIAN_FRONTEND'} = 'noninteractive';
my $cmd = "apt-get -s install ".
	  join(" ", map { quotemeta($_) } split(/\s+/, $packages)).
	  " </dev/null 2>&1";
my $out = &backquote_command($cmd);
my @rv;
foreach my $l (split(/\r?\n/, $out)) {
	if ($l =~ /Inst\s+(\S+)\s+\[(\S+)\]\s+\(([^ \)]+)/ ||
	    $l =~ /Inst\s+(\S+)\s+\[(\S+)\]/) {
		# Format like : Inst telnet [amd64] (5.6.7 Ubuntu)
		my $pkg = { 'name' => $1,
			    'version' => $3 || $2 };
		if ($pkg->{'version'} =~ s/^(\S+)://) {
			$pkg->{'epoch'} = $1;
			}
		push(@rv, $pkg);
		}
	elsif ($l =~ /Inst\s+(\S+)\s+\(([^ \)]+)/) {
		# Format like : Inst telnet (5.6.7 Ubuntu [amd64])
		my $pkg = { 'name' => $1,
			    'version' => $2 };
		if ($pkg->{'version'} =~ s/^(\S+)://) {
			$pkg->{'epoch'} = $1;
			}
		push(@rv, $pkg);
		}
	}
return @rv;
}

# update_system_form()
# Shows a form for updating all packages on the system
sub update_system_form
{
print &ui_subheading($text{'apt_form'});
print &ui_form_start("apt_upgrade.cgi");
print &ui_table_start($text{'apt_header'}, undef, 2);

print &ui_table_row($text{'apt_update'},
	&ui_yesno_radio("update", 1));

print &ui_table_row($text{'apt_mode'},
	&ui_radio("mode", 0, [ [ 2, $text{'apt_mode2'} ],
			       [ 1, $text{'apt_mode1'} ],
			       [ 0, $text{'apt_mode0'} ] ]));

print &ui_table_row($text{'apt_sim'},
	&ui_yesno_radio("sim", 0));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'apt_apply'} ] ]);
}

# update_system_resolve(name)
# Converts a standard package name like apache, sendmail or squid into
# the name used by APT.
sub update_system_resolve
{
local ($name) = @_;
return $name eq "dhcpd" && $gconfig{'os_version'} >= 7 ?
		"isc-dhcp-server" :
       $name eq "dhcpd" && $gconfig{'os_version'} < 7 ?
		"dhcp3-server" :
       $name eq "bind" ? "bind9" :
       $name eq "mysql" && $gconfig{'os_version'} >= 7 ?
		"mysql-client mysql-server" :
       $name eq "mysql" && $gconfig{'os_version'} < 7 ?
		"mysql-client mysql-server mysql-admin" :
       $name eq "apache" ? "apache2" :
       $name eq "squid" && $gconfig{'os_version'} >= 8 ?
		"squid3" :
       $name eq "postgresql" ? "postgresql postgresql-client" :
       $name eq "openssh" ? "ssh" :
       $name eq "openldap" ? "slapd" :
       $name eq "ldap" ? "libnss-ldap libpam-ldap" :
       $name eq "dovecot" ? "dovecot-common dovecot-imapd dovecot-pop3d" :
       $name eq "virtualmin-modules" ? "webmin-.*" :
			       $name;
}

# update_system_available()
# Returns a list of package names and versions that are available from APT
sub update_system_available
{
local (@rv, $pkg, %done);

# Use dump to get versions
&execute_command("$apt_get_command update");
&clean_language();
&open_execute_command(DUMP, "apt-cache dump 2>/dev/null", 1, 1);
while(<DUMP>) {
	if (/^\s*Package:\s*(\S+)/) {
		$pkg = { 'name' => $1 };
		push(@rv, $pkg);
		$done{$1} = $pkg;
		}
	elsif (/^\s*Version:\s*(\S+)/ && $pkg && !$pkg->{'version'}) {
		$pkg->{'version'} = $1;
		if ($pkg->{'version'} =~ /^(\d+):(.*)$/) {
			$pkg->{'epoch'} = $1;
			$pkg->{'version'} = $2;
			}
		}
	elsif (/^\s*File:\s*(\S+)/ && $pkg) {
		$pkg->{'file'} ||= $1;
		}
	}
close(DUMP);
&reset_environment();

# Use search to get descriptions
foreach my $s (&update_system_search('.*')) {
	my $pkg = $done{$s->{'name'}};
	if ($pkg) {
		$pkg->{'desc'} = $s->{'desc'};
		}
	}

&set_pinned_versions(\@rv);
return @rv;
}

# update_system_search(text)
# Returns a list of packages matching some search
sub update_system_search
{
local (@rv, $pkg);
&clean_language();
&open_execute_command(DUMP, "$apt_search_command search ".
			    quotemeta($_[0])." 2>/dev/null", 1, 1);
while(<DUMP>) {
	if (/^(\S+)\s*-\s*(.*)/) {
		push(@rv, { 'name' => $1, 'desc' => $2 });
		}
	elsif (/^(\S)\s+(\S+)\s+-\s*(.*)/) {
		push(@rv, { 'name' => $2, 'desc' => $3 });
		}
	}
close(DUMP);
&reset_environment();
return @rv;
}

# update_system_updates()
# Returns a list of available package updates
sub update_system_updates
{
&execute_command("$apt_get_command update");

# Find held packages by dpkg
local %holds;
if ($config{'package_system'} eq 'debian') {
	&clean_language();
	&open_execute_command(HOLDS, "dpkg --get-selections", 1, 1);
	while(<HOLDS>) {
		if (/^(\S+)\s+hold/) {
			$holds{$1}++;
			}
		}
	close(HOLDS);
	&reset_environment();
	}

if (&has_command("apt-show-versions")) {
	# This awesome command can give us all updates in one hit, and takes
	# pinned versions and backports into account
	local @rv;
	&clean_language();
	&execute_command("apt-show-versions -i");
	&open_execute_command(PKGS, "apt-show-versions 2>/dev/null", 1, 1);
	while(<PKGS>) {
		if (/^(\S+)\/(\S+)\s+upgradeable\s+from\s+(\S+)\s+to\s+(\S+)/ &&
		    !$holds{$1}) {
			# Old format
			local $pkg = { 'name' => $1,
				       'source' => $2,
				       'version' => $4 };
			if ($pkg->{'version'} =~ s/^(\S+)://) {
				$pkg->{'epoch'} = $1;
				}
			push(@rv, $pkg);
			}
		elsif (/^(\S+):(\S+)\/(\S+)\s+(\S+)\s+upgradeable\s+to\s+(\S+)/ && !$holds{$1}) {
			# New format, like 
			# libgomp1:i386/unstable 4.8.2-2 upgradeable to 4.8.2-4
			local $pkg = { 'name' => $1,
				       'arch' => $2,
				       'source' => $3,
				       'version' => $5 };
			if ($pkg->{'version'} =~ s/^(\S+)://) {
				$pkg->{'epoch'} = $1;
				}
			push(@rv, $pkg);
			}
		}
	close(PKGS);
	&reset_environment();
	@rv = &filter_held_packages(@rv);
	foreach my $pkg (@rv) {
		$pkg->{'security'} = 1 if ($pkg->{'source'} =~ /security/i);
		}
	return @rv;
	}
else {
	# Need to manually compose by calling dpkg and apt-cache showpkg
	local %packages;
	local $n = &list_packages();
	local %currentmap;
	for(my $i=0; $i<$n; $i++) {
		local $pkg = { 'name' => $packages{$i,'name'},
			       'oldversion' => $packages{$i,'version'},
			       'desc' => $packages{$i,'desc'},
			       'oldepoch' => $packages{$i,'epoch'} };
		$currentmap{$pkg->{'name'}} ||= $pkg;
		}
	local @rv;
	local @names = grep { !$holds{$_} } keys %currentmap;
	while(scalar(@names)) {
		local @somenames;
		if (scalar(@names) > 100) {
			# Do 100 at a time
			@somenames = @names[0..99];
			@names = @names[100..$#names];
			}
		else {
			# Do the rest
			@somenames = @names;
			@names = ( );
			}
		&clean_language();
		&open_execute_command(PKGS, "apt-cache showpkg ".
			join(" ", @somenames)." 2>/dev/null", 1, 1);
		local $pkg = undef;
		while(<PKGS>) {
			s/\r|\n//g;
			if (/^\s*Package:\s*(\S+)/) {
				$pkg = $currentmap{$1};
				}
			elsif (/^Versions:\s*$/ && $pkg && !$pkg->{'version'}) {
				# Newest version is on next line
				local $ver = <PKGS>;
				$ver =~ s/\s.*\r?\n//;
				local $epoch;
				if ($ver =~ s/^(\d+)://) {
					$epoch = $1;
					}
				$pkg->{'version'} = $ver;
				$pkg->{'epoch'} = $epoch;
				local $newer =
				    $pkg->{'epoch'} <=> $pkg->{'oldepoch'} ||
				    &compare_versions($pkg->{'version'},
						      $pkg->{'oldversion'});
				if ($newer > 0) {
					push(@rv, $pkg);
					}
				}
			}
		close(PKGS);
		&reset_environment();
		}
	@rv = &filter_held_packages(@rv);
	&set_pinned_versions(\@rv);
	return @rv;
	}
}

# set_pinned_versions(&package-list)
# Updates the version and epoch fields in a list of available packages based
# on pinning.
sub set_pinned_versions
{
local ($pkgs) = @_;
local %pkgmap = map { $_->{'name'}, $_ } @$pkgs;
&clean_language();
&open_execute_command(PKGS, "apt-cache policy 2>/dev/null", 1, 1);
while(<PKGS>) { 
	s/\r|\n//g;
	if (/\s+(\S+)\s+\-\>\s+(\S+)/) {
		my ($name, $pin) = ($1, $2);
		my $pkg = $pkgmap{$name};
		if ($pkg) {
			$pkg->{'version'} = $pin;
			$pkg->{'epoch'} = undef;
			if ($pkg->{'version'} =~ s/^(\S+)://) {
				$pkg->{'epoch'} = $1;
				}
			}
		}
	}
close(PKGS);
&reset_environment();
}

# filter_held_packages(package, ...)
# Returns a list of package updates, minus those that are held
sub filter_held_packages
{
my @pkgs = @_;
my %hold;

# Get holds from dpkg
&clean_language();
&open_execute_command(PKGS, "dpkg --get-selections 2>/dev/null", 1, 1);
while(<PKGS>) { 
	if (/^(\S+)\s+hold/) {
		$hold{$1} = 1;
		}
	}
close(PKGS);
&reset_environment();

# Get holds from aptitude
if (&has_command("aptitude")) {
	&clean_language();
	&open_execute_command(PKGS, "aptitude search '~ahold' 2>/dev/null", 1, 1);
	while(<PKGS>) { 
		if (/^\.h\s+(\S+)/) {
			$hold{$1} = 1;
			}
		}
	close(PKGS);
	&reset_environment();
	}

return grep { !$hold{$_->{'name'}} } @pkgs;
}
