# yum-lib.pl
# Functions for installing packages with yum

$yum_config = $config{'yum_config'} || "/etc/yum.conf";

sub list_update_system_commands
{
return ("yum");
}

# update_system_install([package], [&in])
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
print "<b>",&text('yum_install', "<tt>yum $enable -y install $update</tt>"),"</b><p>\n";
print "<pre>";
&additional_log('exec', undef, "yum $enable -y install $update");
local $qm = join(" ", map { quotemeta($_) } split(/\s+/, $update));
&open_execute_command(CMD, "yum $enable -y install $qm </dev/null", 2);
while(<CMD>) {
	s/\r|\n//g;
	if (/^\[(update|install|deps):\s+(\S+)\s+/) {
		push(@rv, $2);
		}
	elsif (/^(Installed|Dependency Installed|Updated|Dependency Updated):\s*(.*)/) {
		# Line like :
		# Updated:
		#   wbt-virtual-server-theme.x86
		local @pkgs = split(/\s+/, $2);
		if (!@pkgs) {
			# Wrapped to next line
			local $pkgs = <CMD>;
			$pkgs =~ s/^\s+//;
			$pkgs =~ s/\s+$//;
			@pkgs = split(/\s+/, $_);
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
	elsif (/^\s+Updating\s+:\s+(\S+)/) {
		# Line like :
		#   Updating       : wbt-virtual-server-theme       1/2 
		push(@rv, $1);
		}
	if (!/ETA/ && !/\%\s+done\s+\d+\/\d+\s*$/) {
		print &html_escape($_."\n");
		}
	}
close(CMD);
print "</pre>\n";
if ($?) {
	print "<b>$text{'yum_failed'}</b><p>\n";
	return ( );
	}
else {
	print "<b>$text{'yum_ok'}</b><p>\n";
	return &unique(@rv);
	}
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
open(SHELL, "yum shell $temp |");
while(<SHELL>) {
	if (/Package\s+(\S+)\s+(\S+)\s+set/i) {
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

# update_system_form()
# Shows a form for updating all packages on the system
sub update_system_form
{
print &ui_subheading($text{'yum_form'});
print &ui_form_start("yum_upgrade.cgi");
print &ui_form_end([ [ undef, $text{'yum_apply'} ] ]);
}

# update_system_resolve(name)
# Converts a standard package name like apache, sendmail or squid into
# the name used by YUM.
sub update_system_resolve
{
local ($name) = @_;
return $name eq "apache" ? "httpd" :
       $name eq "dhcpd" ? "dhcp" :
       $name eq "mysql" ? "mysql mysql-server mysql-devel" :
       $name eq "openssh" ? "openssh openssh-server" :
       $name eq "postgresql" ? "postgresql postgresql-libs postgresql-server" :
       $name eq "openldap" ? "openldap-servers openldap-clients" :
       			  $name;
}

# update_system_available()
# Returns a list of package names and versions that are available from YUM
sub update_system_available
{
local @rv;
local %done;
&open_execute_command(PKG, "yum info", 1, 1);
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
&open_execute_command(PKG, "yum list-sec 2>/dev/null", 1, 1);
while(<PKG>) {
	s/\r|\n//g;
	if (/^\S+\s+security\s+(\S+?)\-([0-9]\S+)\.([^\.]+)$/) {
		local ($name, $ver) = ($1, $2);
		if ($done->{$name}) {
			$done->{$name}->{'source'} = 'security';
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
&open_execute_command(PKG, "yum check-update 2>/dev/null", 1, 1);
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
		$done{$pkg} = $pkg->{'name'};
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

