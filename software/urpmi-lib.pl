# urpmi-lib.pl
# Functions for installing packages with Mandrake urpmi

sub list_update_system_commands
{
return ("urpmi");
}

# update_system_install([package])
# Install some package with urpmi
sub update_system_install
{
local $update = $_[0] || $in{'update'};
local (@rv, @newpacks);
local $cmd = "urpmi --force --auto";
print "<b>",&text('urpmi_install', "<tt>$cmd $update</tt>"),"</b><p>\n";
print "<pre>";
&additional_log('exec', undef, "$cmd $update");
local $qm = join(" ", map { quotemeta($_) } split(/\s+/, $update));
&open_execute_command(CMD, "$cmd $qm </dev/null", 2);
while(<CMD>) {
	s/\r|\n//g;
	if (/installing\s+(\S+)\s+from/) {
		# Found a package
		local $pkg = $1;
		$pkg =~ s/\-\d.*//;	# remove version
		push(@rv, $pkg);
		}
	print &html_escape($_."\n");
	}
close(CMD);
print "</pre>\n";
if ($?) {
	print "<b>$text{'urpmi_failed'}</b><p>\n";
	return ( );
	}
else {
	print "<b>$text{'urpmi_ok'}</b><p>\n";
	return &unique(@rv);
	}
}

# update_system_form()
# Shows a form for updating all packages on the system
sub update_system_form
{
print &ui_subheading($text{'urpmi_form'});
print &ui_form_start("urpmi_upgrade.cgi");
print &ui_submit($text{'urpmi_update'}, "update"),"<br>\n";
print &ui_submit($text{'urpmi_upgrade'}, "upgrade"),"<br>\n";
print &ui_form_end();
}

# update_system_resolve(name)
# Converts a standard package name like apache, sendmail or squid into
# the name used by YUM.
sub update_system_resolve
{
local ($name) = @_;
return $name eq "dhcpd" ? "dhcp-server" :
       $name eq "mysql" ? "mariadb" :
       $name eq "openldap" ? "openldap openldap-servers" :
       $name eq "postgresql" ? "postgresql postgresql-server" :
       $name eq "samba" ? "samba-client samba-server" :
                          $name;
}

# update_system_available()
# Returns a list of package names and versions that are available from URPMI
sub update_system_available
{
local @rv;
local %done;
&open_execute_command(PKG, "urpmq -f --list", 1, 1);
while(<PKG>) {
	if (/^(\S+)\-(\d[^\-]*)\-([^\.]+)\.(\S+)/) {
		next if ($done{$1,$2}++);
		push(@rv, { 'name' => $1,
			    'version' => $2,
			    'release' => $3,
			    'arch' => $4 });
		}
	}
close(PKG);
return @rv;
}

