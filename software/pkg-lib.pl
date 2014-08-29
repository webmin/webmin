# Functions for FreeBSD pkg repository

sub list_update_system_commands
{
return ("pkg");
}

# update_system_install([package], [&in], [no-force])
# Install some package with apt
sub update_system_install
{
my $update = $_[0] || $in{'update'};
my $in = $_[1];
my $force = !$_[2];

# Build and show command to run
$update = join(" ", map { quotemeta($_) } split(/\s+/, $update));
my $cmd = "pkg install ".$update;
print "<b>",&text('pkg_install', "<tt>$cmd</tt>"),"</b><p>\n";
print "<pre>";
&additional_log('exec', undef, $cmd);

# Run it
&open_execute_command(CMD, "yes | $cmd", 2);
while(<CMD>) {
	if (/Installing\s+(\S+)\-(\d\S*)/i) {
		# New package
		push(@rv, $1);
		}
	elsif (/\s+(\S+):\s+(\S+)\s+->\s+(\S+)/) {
		# Upgrading package
		push(@rv, $1);
		}
	print &html_escape("$_");
	}
close(CMD);

print "</pre>\n";
if ($?) { print "<b>$text{'pkg_failed'}</b><p>\n"; }
else { print "<b>$text{'pkg_ok'}</b><p>\n"; }
return @rv;
}

# update_system_search(text)
# Returns a list of packages matching some search
sub update_system_search
{
local (@rv, $pkg);
&clean_language();
&open_execute_command(DUMP, "pkg search -Q comment ".quotemeta($_[0])." 2>/dev/null", 1,1);
while(<DUMP>) {
	if (/^(\S+)-(\d\S*)\s+(\S.*)/) {
		push(@rv, { 'name' => $1,
			    'version' => $2,
			    'desc' => $3 });
		}
	}
close(DUMP);
&reset_environment();
return @rv;
}

# update_system_available()
# Returns a list of package names and versions that are available from YUM
sub update_system_available
{
return &update_system_search(".*");
}

# update_system_updates()
# Returns a list of available package updates
sub update_system_updates
{
my @rv;
&clean_language();
&open_execute_command(DUMP, "yes no | pkg upgrade 2>/dev/null", 1,1);
while(<DUMP>) {
	if (/^\s+(\S+):\s+(\S+)\s+->\s+(\S+)/) {
		push(@rv, { 'name' => $1,
			    'oldversion' => $2,
			    'version' => $3 });
		}
	}
close(DUMP);
&reset_environment();
return @rv;
}

# update_system_resolve(name)
# Converts a standard package name like apache, sendmail or squid into
# the name used by ports.
sub update_system_resolve
{
local ($name) = @_;
return $name eq "apache" ? "apache22 ap22-mod_.*" :
       $name eq "dhcpd" ? "isc-dhcp42-server" :
       $name eq "mysql" ? "mysql-server" :
       $name eq "openssh" ? "openssh-portable" :
       $name eq "postgresql" ? "postgresql-server" :
       $name eq "openldap" ? "openldap-server openldap-client" :
       $name eq "samba" ? "samba36 samba36-smbclient samba36-nmblookup" :
       $name eq "spamassassin" ? "p5-Mail-SpamAssassin" :
       			  $name;
}

1;
