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
	elsif (/^(Installed|Dependency Installed|Updated|Dependency Updated):\s+(.*)/) {
		local @pkgs = split(/\s+/, $2);
		foreach my $p (@pkgs) {
			if ($p !~ /:/ && $p =~ /^(\S+)\.(\S+)$/) {
				my $pname = $1;
				if ($p =~ /[^0-9\.\-\_i]/) {
					push(@rv, $pname);
					}
				}
			}
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
&open_execute_command(PKG, "yum list", 1, 1);
while(<PKG>) {
	next if (/^Setting\s+up/i);
	if (/^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*$/ ||
	    /^(\S+)\.(\S+)\s+(\S+)\s+(\S+)\s*$/) {
		local $name = $1;
		if ($done{$name}) {
			# Seen twice - assume second is better
			$done{$name}->{'version'} = $3;
			$done{$name}->{'source'} = $4;
			if ($done{$name}->{'version'} =~ s/^(\S+)://) {
				$done{$name}->{'epoch'} = $1;
				}
			else {
				$done{$name}->{'epoch'} = undef;
				}
			}
		else {
			# First occurrance
			local $pkg = { 'name' => $1,
				       'arch' => $2,
				       'version' => $3,
				       'source' => $4 };
			if ($pkg->{'version'} =~ s/^(\S+)://) {
				$pkg->{'epoch'} = $1;
				}
			push(@rv, $pkg);
			$done{$pkg->{'name'}} = $pkg;
			}
		}
	}
close(PKG);

# Also run list-sec to find out which are security updates
&open_execute_command(PKG, "yum list-sec", 1, 1);
while(<PKG>) {
	s/\r|\n//g;
	if (/^\S+\s+security\s+(\S+?)\-([0-9]\S+)\.([^\.]+)$/) {
		local ($name, $ver) = ($1, $2);
		if ($done{$name}) {
			$done{$name}->{'source'} = 'security';
			$done{$name}->{'security'} = 1;
			}
		}
	}
close(PKG);

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

