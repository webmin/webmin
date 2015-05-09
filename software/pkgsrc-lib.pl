# Functions for MacOS pkgsrc repository

$ENV{'PATH'} .= ":/usr/pkg/bin:/usr/pkg/sbin";
$pkgin_sqlite_db = "/var/db/pkgin/pkgin.db";

sub list_package_system_commands
{
return ("pkgin", "sqlite3");
}

# execute_pkgin_sql(command)
# Returns an array of rows, each of which is a hash ref from column name to
# value for that row
sub execute_pkgin_sql
{
my ($sql) = @_;
my $errtemp = &transname();
my $cmd = "sqlite3 -header $pkgin_sqlite_db ".quotemeta($sql)." 2>$errtemp";
&open_execute_command(SQL, $cmd, 1, 1);
my $headline = <SQL>;
$headline =~ s/\r|\n//g;
my @cols = split(/\|/, $headline);
while(my $row = <SQL>) {
	$row =~ s/\r|\n//g;
	my @row = split(/\|/, $row);
	my $r = { };
	for(my $i=0; $i<@cols; $i++) {
		$r->{lc($cols[$i])} = $row[$i];
		}
	push(@rv, $r);
	}
close(SQL);
my $ex = $?;
my $err = &read_file_contents($errtemp);
&unlink_file($errtemp);
if ($err || $?) {
	&error("SQL command $sql failed : ".
	       ($err || $headline || "Unknown error"));
	}
return @rv;
}

# list_packages([package]*)
# Fills the array %packages with all or listed packages
sub list_packages
{
my (@names) = @_;
my $sql = "select * from local_pkg";
if (@names) {
	$sql .= " where pkgname in (".join(", ", map { "'$_'" } @names).")";
	}
my @out = &execute_pkgin_sql($sql);
my $i = 0;
my $arch = &backquote_command("uname -m");
$arch =~ s/\r|\n//g;
foreach my $r (@out) {
	$packages{$i,'name'} = $r->{'pkgname'};
	$packages{$i,'version'} = $r->{'pkgvers'};
	$packages{$i,'desc'} = $r->{'comment'};
	$packages{$i,'arch'} = $arch;
	$packages{$i,'class'} = (split(/\s+/, $r->{'categories'}))[0];
	$i++;
	}
return $i;
}

# package_info(package, [version])
# Returns an array of package information in the order
#  name, class, description, arch, version, vendor, installtime
# XXX there doesn't seem to be any pkgsrc command for this
sub package_info
{
my ($name, $ver) = @_;
my $n = &list_packages($name);
return ( ) if (!$n);
return ($packages{0,'name'}, $packages{0,'class'}, $packages{0,'desc'},
	$packages{0,'arch'}, $packages{0,'version'}, undef, undef);
}

# is_package(file)
# Always returns 0, because pkgsrc doesn't support installing from files
sub is_package
{
return 0;
}

# file_packages(file)
# Returns nothing, because pkgsrc doesn't support installing from files
sub file_packages
{
return ();
}

sub package_system
{
return "PKGsrc";
}




sub list_update_system_commands
{
return ("pkgin");
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
my $cmd = "pkgin install ".$update;
print "<b>",&text('pkgsrc_install', "<tt>$cmd</tt>"),"</b><p>\n";
print "<pre>";
&additional_log('exec', undef, $cmd);

# Run it
&open_execute_command(CMD, "yes Y | $cmd", 2);
while(<CMD>) {
	if (/installing\s+(\S+)\-(\d\S*)/i) {
		# New package
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
