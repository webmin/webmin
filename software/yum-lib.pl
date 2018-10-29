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

sub list_update_system_commands
{
return ($yum_command);
}

# update_system_install([packages], [&in])
# Install some package with yum
sub update_system_install
{
local $update = $_[0] || $in{'update'};
local $in = $_[1];
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
$update = join(" ", @names);

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

print "<b>",&text('yum_install', "<tt>$yum_command $enable -y $cmd $update</tt>"),"</b><p>\n";
print "<pre>";
&additional_log('exec', undef, "$yum_command $enable -y install $update");
$SIG{'TERM'} = 'ignore';	# Installing webmin itself may kill this script
local $qm = join(" ", map { quotemeta($_) } @names);
&open_execute_command(CMD, "$yum_command $enable -y $cmd $qm </dev/null", 2);
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
	print "<b>$text{'yum_failed'}</b><p>\n";
	return ( );
	}
else {
	print "<b>$text{'yum_ok'}</b><p>\n";
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
	if (/Package\s+(\S+)\s+(\S+)\s+(set|will\s+be\s+updated)/i) {
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
local ($name) = @_;
local $maria = $gconfig{'real_os_type'} =~ /CentOS|Redhat|Scientific/ &&
	       $gconfig{'real_os_version'} >= 7;
return $name eq "apache" ? "httpd mod_.*" :
       $name eq "dhcpd" ? "dhcp" :
       $name eq "mysql" && $maria ? "mariadb mariadb-server mariadb-devel" :
       $name eq "mysql" && !$maria ? "mysql mysql-server mysql-devel" :
       $name eq "openssh" ? "openssh openssh-server" :
       $name eq "postgresql" ? "postgresql postgresql-libs postgresql-server" :
       $name eq "openldap" ? "openldap-servers openldap-clients" :
       $name eq "ldap" ? "nss-pam-ldapd pam_ldap nss_ldap" :
       $name eq "virtualmin-modules" ? "wbm-.*" :
       			  $name;
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
&open_execute_command(PKG, "$yum_command check-update 2>/dev/null", 1, 1);
while(<PKG>) {
        s/\r|\n//g;
	if (/^(\S+)\.([^\.]+)\s+(\S+)\s+(\S+)/) {
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
open(CONF, $yum_config);
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

1;

