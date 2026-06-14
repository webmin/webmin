# apk-lib.pl
# Functions for Alpine Package Keeper package management

$ENV{'PATH'} .= ":/sbin:/usr/sbin";
$apk_installed_db = "/lib/apk/db/installed";

sub list_package_system_commands
{
return ("apk");
}

sub list_update_system_commands
{
return ("apk");
}

# parse_apk_installed()
# Returns installed packages from APK's package database
sub parse_apk_installed
{
my @rv;
my $pkg = { };
my $last;
open(my $db, "<", $apk_installed_db) || return ();
while(my $line = <$db>) {
	$line =~ s/\r?\n$//;
	if ($line eq "") {
		push(@rv, $pkg) if ($pkg->{'P'});
		$pkg = { };
		$last = undef;
		next;
		}
	if ($line =~ /^([A-Za-z]):(.*)$/) {
		$pkg->{$1} = $2;
		$last = $1;
		}
	elsif ($line =~ /^\t(.*)$/ && defined($last)) {
		$pkg->{$last} .= "\n".$1;
		}
	}
close($db);
push(@rv, $pkg) if ($pkg->{'P'});
return @rv;
}

sub apk_package_class
{
return lc($_[0]) =~ /^[a-e]/ ? "A-E" :
       lc($_[0]) =~ /^[f-j]/ ? "F-J" :
       lc($_[0]) =~ /^[k-o]/ ? "K-O" :
       lc($_[0]) =~ /^[p-t]/ ? "P-T" :
       lc($_[0]) =~ /^[u-z]/ ? "U-Z" : "Other";
}

sub split_apk_name_version
{
my ($nv) = @_;
return ($1, $2) if ($nv =~ /^(.+)-([0-9][^\s]*)$/);
return ($nv, undef);
}

sub apk_package_record
{
my ($name, $ver) = @_;
foreach my $p (&parse_apk_installed()) {
	next if ($p->{'P'} ne $name);
	next if ($ver && $p->{'V'} ne $ver);
	return $p;
	}
return undef;
}

sub apk_quote_packages
{
return join(" ", map { quotemeta($_) } split(/\s+/, $_[0]));
}

# list_packages([package]*)
# Fills the array %packages with a list of all packages
sub list_packages
{
my %wanted = map { $_ => 1 } @_;
my $i = 0;
%packages = ( );
foreach my $p (sort { $a->{'P'} cmp $b->{'P'} } &parse_apk_installed()) {
	next if (@_ && !$wanted{$p->{'P'}});
	$packages{$i,'name'} = $p->{'P'};
	$packages{$i,'class'} = &apk_package_class($p->{'P'});
	$packages{$i,'version'} = $p->{'V'};
	$packages{$i,'desc'} = $p->{'T'};
	$packages{$i,'arch'} = $p->{'A'};
	$packages{$i,'url'} = $p->{'U'};
	$i++;
	}
return $i;
}

# package_search(string)
# Searches installed packages by name and description
sub package_search
{
my ($search) = @_;
my $n = &list_packages();
my $i = 0;
my %old = %packages;
%packages = ( );
for(my $j=0; $j<$n; $j++) {
	if ($old{$j,'name'} =~ /\Q$search\E/i ||
	    $old{$j,'desc'} =~ /\Q$search\E/i) {
		foreach my $k ('name', 'class', 'version', 'desc', 'arch',
			       'url') {
			$packages{$i,$k} = $old{$j,$k};
			}
		$i++;
		}
	}
return $i;
}

# package_info(package, [version])
# Returns name, class, description, arch, version, vendor, installtime, url
sub package_info
{
my ($name, $ver) = @_;
my $p = &apk_package_record($name, $ver);
return ( ) if (!$p);
return ( $p->{'P'}, &apk_package_class($p->{'P'}),
	 $p->{'T'} || $text{'apk_unknown'},
	 $p->{'A'} || $text{'apk_unknown'},
	 $p->{'V'} || $text{'apk_unknown'},
	 $p->{'m'} || "Alpine Linux",
	 undef,
	 $p->{'U'} );
}

sub virtual_package_info
{
return ( );
}

# package_files(package)
# Returns a list of all files in some package
sub package_files
{
my ($name) = @_;
my $qname = quotemeta($name);
my @rv;
&open_execute_command(PKGINFO, "apk info -L $qname 2>/dev/null", 1, 1);
while(<PKGINFO>) {
	s/\r|\n//g;
	next if (!$_ || / contains:$/);
	$_ = "/".$_ if ($_ !~ /^\//);
	push(@rv, $_);
	}
close(PKGINFO);
return @rv;
}

# check_files(package)
# Fills in the %files array with information about files belonging to a package
sub check_files
{
my ($name) = @_;
my @pkgfiles = &package_files($name);
%files = ( );
for(my $i=0; $i<@pkgfiles; $i++) {
	my $path = $pkgfiles[$i];
	my $real = &translate_filename($path);
	my @st = stat($real);
	$files{$i,'path'} = $path;
	$files{$i,'type'} = -l $real ? 3 : -d $real ? 1 : 0;
	$files{$i,'user'} = @st ? getpwuid($st[4]) : undef;
	$files{$i,'group'} = @st ? getgrgid($st[5]) : undef;
	$files{$i,'mode'} = @st ? sprintf("%o", $st[2] & 07777) : undef;
	$files{$i,'size'} = @st ? $st[7] : 0;
	$files{$i,'link'} = readlink($real);
	$files{$i,'error'} = "Does not exist" if (!@st);
	}
return scalar(@pkgfiles);
}

# installed_file(file)
# Fills %file with details of the package that owns a file
sub installed_file
{
my ($path) = @_;
my $qpath = quotemeta($path);
my $out = &backquote_command("apk info -W $qpath 2>&1", 1);
return 0 if ($? || $out !~ / is owned by (\S+)/);
my ($pkg, $ver) = &split_apk_name_version($1);
my $real = &translate_filename($path);
my @st = stat($real);
%file = ( );
$file{'path'} = $path;
$file{'type'} = -l $real ? 3 : -d $real ? 1 : 0;
$file{'user'} = @st ? getpwuid($st[4]) : undef;
$file{'group'} = @st ? getgrgid($st[5]) : undef;
$file{'mode'} = @st ? sprintf("%o", $st[2] & 07777) : undef;
$file{'size'} = @st ? $st[7] : 0;
$file{'link'} = readlink($real);
$file{'packages'} = $pkg;
$file{'versions'} = $ver;
return 1;
}

# is_package(file)
sub is_package
{
my ($path) = @_;
my $qpath = quotemeta($path);
my $out = &backquote_command("tar -tzf $qpath .PKGINFO 2>/dev/null", 1);
return $? ? 0 : 1;
}

# file_packages(file)
# Returns a list of packages in an apk file, in "package description" form
sub file_packages
{
my ($path) = @_;
my $qpath = quotemeta($path);
my $out = &backquote_command("tar -xOzf $qpath .PKGINFO 2>/dev/null", 1);
return ( ) if ($?);
my %info;
foreach my $line (split(/\r?\n/, $out)) {
	if ($line =~ /^(\S+)\s*=\s*(.*)$/) {
		$info{$1} = $2;
		}
	}
return $info{'pkgname'} ? ( $info{'pkgname'}." ".$info{'pkgdesc'} ) : ( );
}

sub install_options
{
print &ui_table_row($text{'apk_untrusted'},
	&ui_yesno_radio("untrusted", 0));
}

# install_package(file, package, [&inputs])
sub install_package
{
my ($path, $package, $inref) = @_;
$inref ||= \%in;
my $qpath = quotemeta($path);
my $args = $inref->{'untrusted'} ? "--allow-untrusted " : "";
my $out = &backquote_logged("apk add $args$qpath 2>&1 </dev/null");
return $? ? "<pre>$out</pre>" : undef;
}

# delete_package(package)
sub delete_package
{
my ($name) = @_;
my $out = &backquote_logged("apk del ".quotemeta($name)." 2>&1 </dev/null");
return $? ? "<pre>$out</pre>" : undef;
}

sub package_dependencies
{
my ($name, $ver) = @_;
my $p = &apk_package_record($name, $ver);
return ( ) if (!$p || !$p->{'D'});
my @rv;
foreach my $dep (split(/\s+/, $p->{'D'})) {
	next if (!$dep);
	$dep =~ s/^\!//;
	if ($dep =~ /^([A-Za-z0-9+_.-]+)([<>=~]+)(\S+)$/) {
		push(@rv, { 'package' => $1,
			    'compare' => $2,
			    'version' => $3 });
		}
	elsif ($dep =~ /^[A-Za-z0-9+_.-]+$/) {
		push(@rv, { 'package' => $dep });
		}
	else {
		push(@rv, { 'other' => $dep });
		}
	}
return @rv;
}

sub package_system
{
return $text{'apk_manager'};
}

sub package_help
{
return "apk";
}

###### Update system functions

sub update_system_search
{
my ($search) = @_;
my $pattern = defined($search) && $search ne "" && $search ne ".*" ?
	"*".$search."*" : "*";
my @rv;
&clean_language();
&open_execute_command(SEARCH, "apk search -v ".quotemeta($pattern)." 2>/dev/null", 1, 1);
while(<SEARCH>) {
	s/\r|\n//g;
	if (/^(.+)-([0-9][^\s]*)\s+-\s+(.*)$/) {
		push(@rv, { 'name' => $1,
			    'version' => $2,
			    'desc' => $3 });
		}
	}
close(SEARCH);
&reset_environment();
return @rv;
}

sub update_system_available
{
&execute_command("apk update");
return &update_system_search(".*");
}

sub update_system_updates
{
my @rv;
&execute_command("apk update");
&clean_language();
&open_execute_command(UPDATES, "apk version -l '<' -v 2>/dev/null", 1, 1);
while(<UPDATES>) {
	s/\r|\n//g;
	if (/^(.+)-([0-9][^\s]*)\s+<\s+(\S+)/) {
		push(@rv, { 'name' => $1,
			    'oldversion' => $2,
			    'version' => $3 });
		}
	}
close(UPDATES);
&reset_environment();
return @rv;
}

sub update_system_install
{
my $update = $_[0] || $in{'update'};
my @rv;
my $qupdate = &apk_quote_packages($update);
my $cmd = "apk add --update --upgrade $qupdate";
print &text('apk_install', "<tt>".&html_escape($cmd)."</tt>"),"\n";
print "<pre data-installer>";
&additional_log('exec', undef, $cmd);
&open_execute_command(CMD, "$cmd 2>&1 </dev/null", 2);
while(<CMD>) {
	if (/\b(?:Installing|Upgrading|Downgrading)\s+(\S+)\s+\(/) {
		push(@rv, $1);
		}
	print &html_escape($_);
	}
close(CMD);
print "</pre>\n";
if ($?) { print "$text{'apk_failed'}<p>\n"; }
else { print "$text{'apk_ok'}<p>\n"; }
return &unique(@rv);
}

sub update_system_resolve
{
my ($name) = @_;
return $name eq "apache" ? "apache2" :
       $name eq "dhcpd" ? "dhcp" :
       $name eq "mysql" ? "mariadb mariadb-client mariadb-server-utils" :
       $name eq "postgresql" ? "postgresql postgresql-client" :
       $name eq "openldap" ? "openldap openldap-clients" :
       $name eq "ldap" ? "openldap openldap-clients" :
       $name eq "dovecot" ? "dovecot" :
       $name eq "samba" ? "samba samba-client" :
       $name eq "openssh" ? "openssh" :
       $name eq "squid" ? "squid" :
			    $name;
}

1;
