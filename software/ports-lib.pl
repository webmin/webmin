# Functions for FreeBSD ports / package management

# update_system_install([package], [&in])
# Install a named package, by buiding the port
sub update_system_install
{
my ($update, $in) = @_;
$update ||= $in{'update'};
my (@rv, @newpacks);
my @want = split(/\s+/, $update);
print "<b>",&text('ports_install', "<tt>$update</tt>"),"</b><p>\n";
print "<pre>";
my $err = 0;
foreach my $w (@want) {
	# Find the package dir
	my $v;
	if ($w =~ /^(\S+)\-(\d\S+)$/) {
		$w = $1;
		$v = $2;
		}
	my @pkgs = grep { $_->{'name'} eq $w &&
			  (!$v || $_->{'version'} eq $v) }
			&update_system_search($w);
	if (!@pkgs) {
		print "No port named $w found!\n";
		$err++;
		next;
		}
	my $pkg = $pkgs[$#pkgs];
	my $dir = "/usr/ports/".$pkg->{'fullname'};

	# Check if already installed
	my @info = &package_info($pkg->{'name'});
	my $upgrade = scalar(@info) ? 1 : 0;

	# Build the packages
	my $cmd = $upgrade ? "cd $dir && make reinstall"
			   : "cd $dir && make install";
	print $cmd,"\n";
	&additional_log('exec', undef, $cmd);
	$ENV{'BATCH'} = 1;
	my @newrv;
	&open_execute_command(CMD, "$cmd </dev/null", 2);
	while(<CMD>) {
		s/\r|\n//g;
		if (/Registering\s+installation\s+for\s+(\S+)\-(\d\S+)/) {
			push(@newrv, $1);
			}
		print &html_escape($_."\n");
		}
	close(CMD);
	$err++ if ($?);
	push(@rv, @newrv);
	}
print "</pre>\n";
if ($err) {
	print "<b>$text{'ports_failed'}</b><p>\n";
	return ( );
	}
else {
	print "<b>$text{'ports_ok'}</b><p>\n";
	return &unique(@rv);
	}
}

# update_system_search(text)
# Returns a list of packages matching some search
sub update_system_search
{
my ($search) = @_;
&clean_language();
my $cmd = "cd /usr/ports && make search key=".quotemeta($search);
my $out = &backquote_command("$cmd 2>&1 </dev/null");
if ($out =~ /make\s+fetchindex/) {
	&execute_command("cd /usr/ports && make fetchindex");
	$out = &backquote_command("$cmd 2>&1 </dev/null");
	}
foreach my $line (split(/\r?\n/, $out)) {
	if ($line =~ /Port:\s+(\S+)\-(\d\S+)/) {
		my $p = { 'name' => $1,
			  'version' => $2,
			  'select' => $1."-".$2 };
		push(@rv, $p);
		}
	elsif ($line =~ /Path:\s+\/usr\/ports\/(\S+\/(\S+))/ && @rv) {
		$rv[$#rv]->{'fullname'} = $1;
		}
	elsif ($line =~ /Info:\s+(.*)/ && @rv) {
		$rv[$#rv]->{'desc'} = $1;
		}
	}
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

# update_system_available()
# Returns a list of package names and versions that are available from ports
sub update_system_available
{
local @rv;
&execute_command("cd /usr/ports && make fetchindex");
&open_execute_command(PKG, "cd /usr/ports && make search 'key=.*'", 2, 1);
my @rv;
while(my $line = <PKG>) {
	s/\r|\n//g;
	if ($line =~ /Port:\s+(\S+)\-(\d\S+)/) {
		my $p = { 'name' => $1,
			  'version' => $2,
			  'select' => $1."-".$2 };
		push(@rv, $p);
		}
	elsif ($line =~ /Path:\s+\/usr\/ports\/(\S+\/(\S+))/ && @rv) {
		$rv[$#rv]->{'fullname'} = $1;
		}
	elsif ($line =~ /Info:\s+(.*)/ && @rv) {
		$rv[$#rv]->{'desc'} = $1;
		}
	}
return @rv;
}

1;
