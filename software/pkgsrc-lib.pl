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
	$packages{$i,'size'} = $r->{'size_pkg'};
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

# check_files(package, version)
# Fills in the %files array with information about the files belonging
# to some package. Values in %files are  path type user group size error
sub check_files
{
my ($name, $ver) = @_;
my @files = &package_files($name, $ver);
my %errs;
&open_execute_command(CHECK, "pkg_admin check ".quotemeta($name), 1, 1);
while(<CHECK>) {
	if (/^(\/\S+)\s+(.*)/) {
		$errs{$1} = $2;
		}
	}
close(CHECK);
%files = ( );
for(my $i=0; $i<@files; $i++) {
	my @st = stat($files[$i]);
	$files{$i,'path'} = $files[$i];
	$files{$i,'type'} = -l $files[$i] ? 3 :
			    -d $files[$i] ? 1 : 0;
	$files{$i,'user'} = getpwuid($st[4]);
	$files{$i,'group'} = getgrgid($st[5]);
	$files{$i,'mode'} = sprintf "%o", $st[2] & 07777;
	$files{$i,'size'} = $st[7];
	$files{$i,'link'} = readlink($real);
	$files{$i,'error'} = $errs{$files[$i]};
	}
return scalar(@files);
}

# package_files(package, [version])
# Returns a list of all files in some package
sub package_files
{
my ($name, $ver) = @_;
&open_execute_command(DUMP, "pkg_admin dump", 1, 1);
while(<DUMP>) {
	if (/file:\s+(\S.*\S)\s+pkg:\s+(\S+)\-/ && $2 eq $name) {
		push(@rv, $1);
		}
	}
close(DUMP);
return @rv;
}

# installed_file(file)
# Given a filename, fills %file with details of the given file and returns 1.
# If the file is not known to the package system, returns 0
# Usable values in %file are  path type user group mode size packages
sub installed_file
{
# XXX
local($pkg, @w, $_, @pkgs, @vers);
undef(%file);
local $qm = quotemeta($_[0]);
$pkg = &backquote_command("rpm -q -f $qm --queryformat \"%{NAME}\\n\" 2>&1", 1);
if ($pkg =~ /not owned/ || $?) { return 0; }
@pkgs = split(/\n/, $pkg);
$pkg = &backquote_command("rpm -q -f $qm --queryformat \"%{VERSION}-%{RELEASE}\\n\" 2>&1", 1);
@vers = split(/\n/, $pkg);
&open_execute_command(RPM, "rpm -q $pkgs[0] -l --dump", 1, 1);
while(<RPM>) {
	chop;
	@w = split(/ /);
	if ($w[0] eq $_[0]) {
		$file{'packages'} = join(' ', @pkgs);
		$file{'versions'} = join(' ', @vers);
		$file{'path'} = $w[0];
		if ($w[10] ne "X") { $files{$i,'link'} = $w[10]; }
		$file{'type'} = $w[10] ne "X" ? 3 :
				(-d &translate_filename($w[0])) ? 1 :
				$w[7] ? 5 : 0;
		$file{'user'} = $w[5];
		$file{'group'} = $w[6];
		$file{'mode'} = substr($w[4], -4);
		$file{'size'} = $w[1];
		last;
		}
	}
close(RPM);
return 1;
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
my $cmd = "pkgin -y install ".$update;
print "<b>",&text('pkgsrc_install', "<tt>$cmd</tt>"),"</b><p>\n";
print "<pre>";
&additional_log('exec', undef, $cmd);

# Run it
&open_execute_command(CMD, "$cmd", 2);
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
