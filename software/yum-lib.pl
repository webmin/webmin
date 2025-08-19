# yum-lib.pl
# Functions for installing packages with yum

if ($config{'yum_config'}) {
	$yum_config = $config{'yum_config'};
	}
elsif (&has_command("yum")) {
	$yum_config = "/etc/yum.conf";
	}
elsif (&has_command("dnf")) {
	$yum_config = "/etc/dnf/dnf.conf";
	}

$yum_command = &has_command("dnf") || &has_command("yum") || "yum";
$yum_repos_dir = "/etc/yum.repos.d";

sub list_update_system_commands
{
return ($yum_command);
}

# update_system_install([packages], [&in], [no-force], [flags])
# Install some package with yum
sub update_system_install
{
local $update = $_[0] || $in{'update'};
local $in = $_[1];
local $force = !$_[2];
local $flags = $_[3];
local $qflags;
$qflags = &trim(join(" ", map { quotemeta($_) } split(/ /, $flags)))
	if ($flags);
$update =~ s/\.\*/\*/g;
local $enable;
if ($in->{'enablerepo'}) {
	$enable = "enablerepo=".quotemeta($in->{'enablerepo'});
	}
local (@rv, @newpacks);

# If there are multiple architectures to update for a package, split them out
local @updates = split(/\s+/, $update);
local @names = map { &append_architectures($_) } split(/\s+/, $update);
if (@names == 1) {
	@names = ( $update );
	}
$update = join(" ", map { quotemeta($_) } @names);

# Work out command to use - for DNF, upgrades need to use the update command
local $cmd;
if ($yum_command =~ /dnf$/) {
	local @pinfo = &package_info($updates[0]);
	if ($pinfo[0]) {
		$cmd = "update";
		}
	else {
		$cmd = "install";
		}
	}
else {
	$cmd = "install";
	}

# Work out the command to run, which may enable some repos
my $uicmd = "$yum_command $enable -y $cmd ".join(" ", @names);
$uicmd .= " $flags" if ($flags);
my $fullcmd = "$yum_command $enable -y $cmd $update";
$fullcmd .= " $qflags" if ($flags);
foreach my $u (@updates) {
	my $repo = &update_system_repo($u);
	if ($repo) {
		$fullcmd = "$yum_command -y $cmd $repo ; $fullcmd";
		}
	}

print &text('yum_install', "<tt>".&html_escape($uicmd)."</tt>"),"\n";
print "<pre data-installer>";
&additional_log('exec', undef, $fullcmd);
$SIG{'TERM'} = 'ignore';	# Installing webmin itself may kill this script
&open_execute_command(CMD, "$fullcmd </dev/null", 2);
while(<CMD>) {
	s/\r|\n//g;
	if (/^\[(update|install|deps):\s+(\S+)\s+/) {
		push(@rv, $2);
		}
	elsif (/^(Installed|Dependency Installed|Updated|Dependency Updated|Upgraded):\s*(.*)/) {
		# Line like :
		# Updated:
		#   wbt-virtual-server-theme.x86
		local @pkgs = split(/\s+/, $2);
		if (!@pkgs) {
			# Wrapped to next line(s)
			while(1) {
				local $pkgs = <CMD>;
				last if (!$pkgs);
				print &html_escape($pkgs);
				$pkgs =~ s/^\s+//;
				$pkgs =~ s/\s+$//;
				my @linepkgs = split(/\s+/, $_);
				last if (!@linepkgs);
				push(@pkgs, @linepkgs);
				}
			}
		foreach my $p (@pkgs) {
			if ($p !~ /:/ && $p =~ /^(\S+)\.(\S+)$/) {
				my $pname = $1;
				if ($p =~ /[^0-9\.\-\_i]/) {
					push(@rv, $pname);
					}
				}
			}
		}
	elsif (/^\s+(Updating|Installing|Upgrading)\s+:\s+(\S+)/) {
		# Line like :
		#   Updating       : wbt-virtual-server-theme       1/2 
		# or
		#   Installing : 2:nmap-5.51-2.el6.i686             1/1
		local $pkg = $2;
		$pkg =~ s/^\d://;	# Strip epoch from front
		$pkg =~ s/\-\d.*$//;	# Strip version number from end
		push(@rv, $pkg);
		}
	elsif (/\]\s+(Upgrading|Installing)\s+(\S+)/) {
		# Line like :
		# [3/8] Upgrading libcurl-0:8.11.1-5.fc42 100% ...
		local $pkg = $2;
		$pkg =~ s/:\d.*$//;	# Strip version number from end
		push(@rv, $pkg);
		}
	if (!/ETA/ && !/\%\s+done\s+\d+\/\d+\s*$/) {
		print &html_escape($_."\n");
		}
	if ($update =~ /perl\(/ && /No\s+package\s+.*available/i) {
		$nopackage = 1;
		}
	}
close(CMD);
print "</pre>\n";
if ($? || $nopackage) {
	print "$text{'yum_failed'}<p>\n";
	return ( );
	}
else {
	print "$text{'yum_ok'}<p>\n";
	return &unique(@rv);
	}
}

# append_architectures(package)
# Given a package name, if it has multiple architectures return the name with
# each appended
sub append_architectures
{
my ($name) = @_;
local %packages;
my $n = &list_packages($name);
return ( $name ) if (!$n);
my @rv;
for(my $i=0; $i<$n; $i++) {
	if ($packages{$i,'arch'}) {
		push(@rv, $packages{$i,'name'}.".".$packages{$i,'arch'});
		}
	else {
		push(@rv, $packages{$i,'name'});
		}
	}
@rv = &unique(@rv);
return @rv;
}

# update_system_operations(packages)
# Given a list of packages, returns a list containing packages that will
# actually get installed, each of which is a hash ref with name and version.
sub update_system_operations
{
my ($packages) = @_;
my $temp = &transname();
&open_tempfile(SHELL, ">$temp", 0, 1);
&print_tempfile(SHELL, "install $packages\n");
&print_tempfile(SHELL, "transaction solve\n");
&close_tempfile(SHELL);
my @rv;
open(SHELL, "$yum_command shell $temp |");
while(<SHELL>) {
	if (/Package\s+(\S+)\s+(\S+)\s+(set|will\s+be\s+an\s+update)/i) {
		my $pkg = { 'name' => $1,
			    'version' => $2 };
		if ($pkg->{'name'} =~ s/\.([^\.]+)$//) {
			$pkg->{'arch'} = $1;
			}
		if ($pkg->{'version'} =~ s/^(\S+)://) {
			$pkg->{'epoch'} = $1;
			}
		push(@rv, $pkg);
		}
	}
close(SHELL);
&unlink_file($temp);
return @rv;
}

# show_update_system_opts()
# Returns HTML for enabling a repository, if any are disabled
sub show_update_system_opts
{
local @pinfo = &package_info("yum");
if (&compare_versions($pinfo[4], "2.1.10") > 0) {
	local $conf = &get_yum_config();
	local @ena;
	foreach my $r (@$conf) {
		if ($r->{'values'}->{'enabled'} eq '0') {
			push(@ena, $r->{'name'});
			}
		}
	if (@ena) {
		return $text{'yum_enable'}." ".
		       &ui_select("enablerepo", "",
				  [ [ "", $text{'yum_none'} ],
				    map { [ $_ ] } @ena ]);
		}
	}
return undef;
}

# update_system_resolve(name)
# Converts a standard package name like apache, sendmail or squid into
# the name used by YUM.
sub update_system_resolve
{
my ($name) = @_;
$name = $name eq "apache" ? "httpd mod_.*" :
        $name eq "dhcpd" ? "dhcp dhcp-server" :
        $name eq "mysql" ? "perl-DBD-MySQL mariadb mariadb-server mysql mysql-server" :
        $name eq "openssh" ? "openssh openssh-server" :
        $name eq "postgresql" ? "postgresql postgresql-libs postgresql-server" :
        $name eq "openldap" ? "openldap-servers openldap-clients" :
        $name eq "ldap" ? "nss-pam-ldapd pam_ldap nss_ldap" :
        $name eq "virtualmin-modules" ? "wbm-.*" : $name;
my $flags;
$flags = '--skip-broken' if ($_[0] =~ /^dhcpd|mysql$/);
return wantarray ? ($name, $flags) : $name;
}

# update_system_repo(package)
# Returns the extra repo package that needs to be installed first before
# installing some package, if needed
sub update_system_repo
{
local ($name) = @_;
return $name eq "certbot" ? "epel-release" : undef;
}

# update_system_available()
# Returns a list of package names and versions that are available from YUM
sub update_system_available
{
local @rv;
local %done;
&open_execute_command(PKG, "$yum_command info", 1, 1);
while(<PKG>) {
	s/\r|\n//g;
	if (/^Name\s*:\s*(\S+)/) {
		if ($done{$1}) {
			# Seen before .. update with newer info. This can happen
			# when YUM shows the installed version first.
			$pkg = $done{$1};
			delete($pkg->{'epoch'});
			delete($pkg->{'version'});
			}
		else {
			# Start of a new package
			$pkg = { 'name' => $1 };
			$done{$pkg->{'name'}} = $pkg;
			push(@rv, $pkg);
			}
		}
	elsif (/^Arch\s*:\s*(\S+)/) {
		$pkg->{'arch'} = $1;
		}
	elsif (/^Version\s*:\s*(\S+)/) {
		$pkg->{'version'} = $1;
		if ($pkg->{'version'} =~ s/^(\S+)://) {
			$pkg->{'epoch'} = $1;
			}
		}
	elsif (/^Release\s*:\s*(\S+)/) {
		$pkg->{'version'} .= "-".$1;
		}
	elsif (/^Repo\s*:\s*(\S+)/) {
		$pkg->{'source'} = $1;
		}
	elsif (/^Summary\s*:\s*(\S.*)/) {
		$pkg->{'desc'} = $1;
		}
	elsif (/^Epoch\s*:\s*(\S.*)/) {
		$pkg->{'epoch'} = $1;
		}
	}
close(PKG);
@rv = grep { $_->{'arch'} ne 'src' } @rv;
&set_yum_security_field(\%done);
return @rv;
}

# set_yum_security_field(&package-hash)
# Set security field on packages which are security updates
sub set_yum_security_field
{
local ($done) = @_;
&open_execute_command(PKG, "$yum_command updateinfo list sec 2>/dev/null", 1, 1);
while(<PKG>) {
	s/\r|\n//g;
	if (/^\S+\s+\S+\s+(\S+?)\-([0-9]\S+)\.([^\.]+)$/) {
		local ($name, $ver) = ($1, $2);
		if ($done->{$name}) {
			$done->{$name}->{'source'} ||= 'security';
			$done->{$name}->{'security'} = 1;
			}
		}
	}
close(PKG);
&open_execute_command(PKG, "$yum_command list-sec 2>/dev/null", 1, 1);
while(<PKG>) {
	s/\r|\n//g;
	next if (/^(Loaded|updateinfo)/);
	if (/^\S+\s+\S+\s+(\S+?)\-([0-9]\S+)\.([^\.]+)$/) {
		local ($name, $ver) = ($1, $2);
		if ($done->{$name}) {
			$done->{$name}->{'source'} ||= 'security';
			$done->{$name}->{'security'} = 1;
			}
		}
	}
close(PKG);
}

# update_system_updates()
# Returns a list of package updates available from yum
sub update_system_updates
{
local @rv;
local %done;
if ($yum_command =~ /dnf/) {
	&open_execute_command(PKG, "$yum_command check-update 2>/dev/null", 1, 1);
	}
else {
	&open_execute_command(PKG, "$yum_command check-update 2>/dev/null | tr '\n' '#' | sed -e 's/# / /g' | tr '#' '\n'", 1, 1);
	}
while(<PKG>) {
        s/\r|\n//g;
	if (/^(\S+)\.([^\.]+)\s+(\S+)\s+(\S+)/ && $2 ne 'src') {
		local $pkg = { 'name' => $1,
			       'arch' => $2,
			       'version' => $3,
			       'source' => $4 };
		if ($pkg->{'version'} =~ s/^(\S+)://) {
			$pkg->{'epoch'} = $1;
			}
		$done{$pkg->{'name'}} = $pkg;
		push(@rv, $pkg);
		}
	last if (/Obsoleting\s+Packages/i);
	}
close(PKG);
&set_yum_security_field(\%done);
return @rv;
}

# get_yum_config()
# Returns entries from the YUM config file, as a list of hash references
sub get_yum_config
{
local @rv;
local $sect;
open(CONF, "<".$yum_config);
while(<CONF>) {
	s/\r|\n//g;
	s/^\s*#.*$//;
	if (/^\s*\[(.*)\]/) {
		# Start of a section
		$sect = { 'name' => $1,
			  'values' => { } };
		push(@rv, $sect);
		}
	elsif (/^\s*(\S+)\s*=\s*(.*)/ && $sect) {
		# Value in a section
		$sect->{'values'}->{lc($1)} = $2;
		}
	}
close(CONF);
return \@rv;
}

# list_package_repos()
# Returns a list of configured repositories
sub list_package_repos
{
my @rv;

# Parse the raw repo files
my $repo;
foreach my $f (glob("$yum_repos_dir/*.repo")) {
	my $lref = &read_file_lines($f, 1);
	my $lnum = 0;
	foreach my $l (@$lref) {
		$l =~ s/#.*$//;
		if ($l =~ /^\[(\S+)\]/) {
			# Start of a new repo
			$repo = { 'file' => $f,
				  'line' => $lnum,
				  'eline' => $lnum,
				  'id' => $1,
				};
			push(@rv, $repo);
			}
		elsif ($l =~ /^([^= ]+)=(.*)$/ && $repo) {
			# Line in a repo
			$repo->{'raw'}->{$1} = $2;
			$repo->{'eline'} = $lnum;
			}
		$lnum++;
		}
	}

# Extract common information
foreach my $repo (@rv) {
	my $name = $repo->{'raw'}->{'name'};
	$name =~ s/\s*-.*//;
	$name =~ s/\s*\$[a-z0-9]+//gi;
	$repo->{'name'} = $repo->{'id'}." (".$name.")";
	$repo->{'url'} = $repo->{'raw'}->{'baseurl'} ||
			 $repo->{'raw'}->{'mirrorlist'};
	$repo->{'enabled'} = defined($repo->{'raw'}->{'enabled'}) ?
				$repo->{'raw'}->{'enabled'} : 1;
	}

return @rv;
}

# create_repo_form()
# Returns HTML for a package repository creation form
sub create_repo_form
{
my $rv;
$rv .= &ui_table_row($text{'yum_repo_id'},
		     &ui_textbox("id", undef, 20));
$rv .= &ui_table_row($text{'yum_repo_name'},
		     &ui_textbox("name", undef, 60));
$rv .= &ui_table_row($text{'yum_repo_url'},
		     &ui_textbox("url", undef, 60));
$rv .= &ui_table_row($text{'yum_repo_gpg'},
		     &ui_opt_textbox("gpg", undef, 60, $text{'yum_repo_none'}));
return $rv;
}

# create_repo_parse(&in)
# Parses input from create_repo_form, and returns either a new repo object or
# an error string
sub create_repo_parse
{
my ($in) = @_;
my $repo = { 'raw' => { 'enabled' => 1 } };

# ID must be valid and unique
$in->{'id'} =~ /^[a-z0-9\-\_]+$/i || return $text{'yum_repo_eid'};
my ($clash) = grep { $_->{'id'} eq $in->{'id'} } &list_package_repos();
$clash && return $text{'yum_repo_eidclash'};
$repo->{'id'} = $in->{'id'};

# Human-readable repo name
$in->{'name'} =~ /\S/ || return $text{'yum_repo_ename'};
$repo->{'raw'}->{'name'} = $in->{'name'};

# Base URL
$in->{'url'} =~ /^(http|https):/ || return $text{'yum_repo_eurl'};
$repo->{'raw'}->{'baseurl'} = $in->{'url'};

# GPG key file
if (!$in->{'gpg_def'}) {
	-r $in->{'gpg'} || return $text{'yum_repo_egpg'};
	$repo->{'raw'}->{'gpgcheck'} = 1;
	$repo->{'raw'}->{'gpgkey'} = 'file://'.$in->{'gpg'};
	}

return $repo;
}

# create_package_repo(&repo)
# Creates a new repository from the given hash (returned by create_repo_parse)
sub create_package_repo
{
my ($repo) = @_;
my $file = "$yum_repos_dir/$repo->{'id'}.repo";
-r $file && return $text{'yum_repo_efile'};

&lock_file($file);
my $lref = &read_file_lines($file);
push(@$lref, "[$repo->{'id'}]");
foreach my $r (keys %{$repo->{'raw'}}) {
	push(@$lref, $r."=".$repo->{'raw'}->{$r});
	}
&flush_file_lines($file);
&unlock_file($file);

return undef;
}

# delete_package_repo(&repo)
# Delete a repository from it's config file. Does not delete the file even if
# empty, to prevent it from being re-created if it came from an RPM package.
sub delete_package_repo
{
my ($repo) = @_;
&lock_file($repo->{'file'});
my $lref = &read_file_lines($repo->{'file'});
splice(@$lref, $repo->{'line'}, $repo->{'eline'}-$repo->{'line'}+1);
&flush_file_lines($repo->{'file'});
&unlock_file($repo->{'file'});
}

# enable_package_repo(&repo, enable?)
# Enable or disable a repository
sub enable_package_repo
{
my ($repo, $enable) = @_;
&lock_file($repo->{'file'});
my $lref = &read_file_lines($repo->{'file'});
my $e = "enabled=".($enable ? 1 : 0);
if (defined($repo->{'raw'}->{'enabled'})) {
	# There's a line to update already
	for(my $i=$repo->{'line'}; $i<=$repo->{'eline'}; $i++) {
		if ($lref->[$i] =~ /^enabled=/) {
			$lref->[$i] = $e;
			last;
			}
		}
	}
else {
	# Need to add a line
	splice(@$lref, $repo->{'eline'}, 0, $e);
	}
&flush_file_lines($repo->{'file'});
&unlock_file($repo->{'file'});
}

1;

