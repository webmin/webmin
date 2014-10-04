=head1 servers-lib.pl

Functions for managing remote Webmin servers, which can be monitored or used
for RPC operations. Example code :

 foreign_require("servers", "servers-lib.pl");
 $newserv = { 'host' => 'box.foo.com',
              'port' => 10000,
              'ssl' => 1,
              'user' => 'root',
              'pass' => 'smeg',
              'fast' => 1 };
 servers::save_server($newserv);
 remote_foreign_require($newserv, 'webmin', 'webmin-lib.pl');
 $ver = remote_foreign_call($newserv, 'webmin', 'get_webmin_version');

=cut

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
use WebminCore;
use Socket;
our (%text, %config, %gconfig, $module_config_directory);
&init_config();

our %access = &get_module_acl();
our $cron_cmd = "$module_config_directory/auto.pl";
our @cluster_modules = ( "cluster-software" );

our @server_types = (
		  # Linux sub-types, which have to come first
		  [ 'asianux', 'Asianux', undef, 'Asianux' ],
		  [ 'centos', 'CentOS Linux', undef, 'CentOS' ],
		  [ 'ubuntu', 'Ubuntu Linux', undef, 'Ubuntu' ],
		  [ 'fedora', 'Fedora Linux', undef, 'Fedora' ],
		  [ 'redflag', 'Red Flag Linux', undef, 'RedFlag' ],
		  [ 'amazon', 'Amazon Linux', undef, 'Amazon' ],

		  # Linux variants with a type code
		  [ 'cobalt', 'Cobalt Linux', 'cobalt-linux' ],
		  [ 'debian', 'Debian Linux', 'debian-linux' ],
		  [ 'caldera', 'OpenLinux', 'open-linux' ],
		  [ 'mandrake', 'Mandrake Linux', 'mandrake-linux' ],
		  [ 'msc', 'MSC.Linux', 'msc-linux' ],
		  [ 'redhat', 'Redhat Linux', 'redhat-linux' ],
		  [ 'slackware', 'Slackware Linux', 'slackware-linux' ],
		  [ 'suse', 'SuSE Linux', 'suse-linux' ],
		  [ 'turbo', 'TurboLinux', 'turbo-linux' ],
		  [ 'linux', 'Linux', '.*-linux' ],

		  # Other operating systems
		  [ 'freebsd', 'FreeBSD', 'freebsd' ],
		  [ 'solaris', 'Solaris', 'solaris' ],
		  [ 'hpux', 'HP/UX', 'hpux' ],
		  [ 'sco', 'SCO', '(openserver|unixware)' ],
		  [ 'mac', 'Mac OS X', 'macos' ],
		  [ 'irix', 'IRIX', 'irix' ],
		  [ 'windows', 'Windows', 'windows' ],
		  [ 'unknown', $text{'lib_other'} ],
		);

=head2 list_servers

Returns a list of registered Webmin servers. Each is a hash ref, with the
following keys :

=item id - A unique ID for this server, separate from the hostname.

=item host - The full Internet hostname or IP address.

=item port - Port number that Webmin listens on, such as 10000.

=item ssl - Set to 1 if Webmin is in SSL mode.

=item group - A tab-separated list of group names that this server is in.

=item desc - An optional human-readable description.

=item fast - Set to 1 if fast RPC mode (using non-HTTP TCP connections on ports 10001 and above) is used, 0 for only HTTP.

=item user - The login used to access Webmin on this system, such as root or admin.

=item pass - The password for the username above.

=item autouser - Set to 1 if the admin will be prompted for a username and password when accessing this remote system in this module's UI.

=item sameuser - Set to 1 if this current login and password will be used to login to this remote system.

=cut
sub list_servers
{
my ($f, @rv);
opendir(DIR, $module_config_directory);
while($f = readdir(DIR)) {
	if ($f =~ /^(\S+)\.serv$/) {
		push(@rv, &get_server($1));
		}
	}
closedir(DIR);
return @rv;
}

=head2 list_servers_sorted(applyacl)

Returns a list of servers, sorted according to the module configuration.
The format is the same as list_servers.

=cut
sub list_servers_sorted
{
my @servers = &list_servers();
if ($_[0]) {
	@servers = grep { &can_use_server($_) } @servers;
	}
if ($config{'sort_mode'} == 1) {
	@servers = sort { $a->{'host'} cmp $b->{'host'} } @servers;
	}
elsif ($config{'sort_mode'} == 2) {
	@servers = sort { lc($a->{'desc'} ? $a->{'desc'} : $a->{'host'}) cmp
		   lc($b->{'desc'} ? $b->{'desc'} : $b->{'host'}) } @servers;
	}
elsif ($config{'sort_mode'} == 3) {
	@servers = sort { $a->{'type'} cmp $b->{'type'} } @servers;
	}
elsif ($config{'sort_mode'} == 4) {
	@servers = sort { &to_ipaddress($a->{'host'}) cmp
			  &to_ipaddress($b->{'host'}) } @servers;
	}
elsif ($config{'sort_mode'} == 5) {
	@servers = sort { $a->{'group'} cmp $b->{'group'} } @servers;
	}
return @servers;
}

=head2 get_server(id)

Given a remote server's unique ID, returns the hash reference in the same
format as list_serves.

=cut
sub get_server
{
my $serv = { };
$serv->{'id'} = $_[0];
&read_file("$module_config_directory/$_[0].serv", $serv) || return undef;
$serv->{'file'} = "$module_config_directory/$_[0].serv";
return $serv;
}

=head2 save_server(&server)

Updates a Webmin server on disk, based on the details in the given hash ref,
which must be in the same format as list_servers.

=cut
sub save_server
{
my ($serv) = @_;
$serv->{'id'} ||= time().$$;
&lock_file("$module_config_directory/$serv->{'id'}.serv");
&write_file("$module_config_directory/$serv->{'id'}.serv", $_[0]);
chmod(0600, "$module_config_directory/$serv->{'id'}.serv");
&unlock_file("$module_config_directory/$serv->{'id'}.serv");
$main::remote_servers_cache{$serv->{'host'}} =
   $main::remote_servers_cache{$serv->{'host'}.":".$serv->{'port'}} = $serv;
}

=head2 delete_server(id)

Deletes the Webmin server details identified by the given ID.

=cut
sub delete_server
{
my ($id) = @_;
&unlink_logged("$module_config_directory/$id.serv");
undef(%main::remote_servers_cache);
}

=head2 can_use_server(&server)

Returns 1 if the current Webmin user can use and edit the server specified
by the given hash ref.

=cut
sub can_use_server
{
return 1 if ($access{'servers'} eq '*');
foreach my $s (split(/\s+/, $access{'servers'})) {
	return 1 if ($_[0]->{'host'} eq $s ||
		     $_[0]->{'id'} eq $s);
	}
return 0;
}

=head2 list_all_groups([&servers])

Returns a list of all Webmin server groups and their members, each of
which is a hash ref with the keys :

=item name - A unique group name.

=item members - An array ref of server hostnames.

=cut
sub list_all_groups
{
my (@rv, %gmap, $s, $f, $gn);

# Add webmin servers groups
foreach $s (grep { $_->{'group'} } ($_[0] ? @{$_[0]} : &list_servers())) {
	foreach $gn (split(/\t+/, $s->{'group'})) {
		my $grp = $gmap{$gn};
		if (!$grp) {
			$gmap{$gn} = $grp = { 'name' => $gn, 'type' => 0 };
			push(@rv, $grp);
			}
		push(@{$grp->{'members'}}, $s->{'host'});
		}
	}

# Add MSC cluster groups
if ($config{'groups_dir'} && opendir(DIR, $config{'groups_dir'})) {
	foreach $f (readdir(DIR)) {
		next if ($f eq '.' || $f eq '..');
		my $grp = $gmap{$f};
		if (!$grp) {
			$gmap{$f} = $grp = { 'name' => $f, 'type' => 1 };
			push(@rv, $grp);
			}
		open(GROUP, "$config{'groups_dir'}/$f");
		while(<GROUP>) {
			s/\r|\n//g;
			s/#.*$//;
			if (/(\S*)\[(\d)-(\d+)\](\S*)/) {
				# Expands to multiple hosts
				push(@{$grp->{'members'}},
				     map { $1.$_.$4 } ($2 .. $3));
				}
			elsif (/(\S+)/) {
				push(@{$grp->{'members'}}, $1);
				}
			}
		close(GROUP);
		}
	closedir(DIR);
	}

# Fix up MSC groups that include other groups
while(1) {
	my ($grp, $any);
	foreach $grp (@rv) {
		my @mems;
		foreach my $m (@{$grp->{'members'}}) {
			if ($m =~ /^:(.*)$/) {
				push(@mems, @{$gmap{$1}->{'members'}});
				$any++;
				}
			else {
				push(@mems, $m);
				}
			}
		$grp->{'members'} = \@mems;
		}
	last if (!$any);
	}

return @rv;
}

=head2 logged_in(&serv)

For internal use only.

=cut
sub logged_in
{
my $id = $_[0]->{'id'};
if ($ENV{'HTTP_COOKIE'} =~ /$id=([A-Za-z0-9=]+)/) {
	return split(/:/, &decode_base64("$1"));
	}
else {
	return ();
	}
}

=head2 get_server_types()

Returns a list of operating system types known to this module. Each element
is an array ref with the elements :

=item Internal OS code, such as 'centos'.

=item Human-readable OS name, such as 'CentOS Linux'.

=item Webmin OS code for this type, like 'redhat-linux'.

=item Webmin OS name for this type.

=cut
sub get_server_types
{
return @server_types;
}

=head2 this_server

Returns a fake servers-list entry for this server.

=cut
sub this_server
{
my $type = 'unknown';
foreach my $s (@server_types) {
	if ($s->[2] && $gconfig{'os_type'} =~ /^$s->[2]$/ ||
	    $s->[3] && $gconfig{'real_os_type'} =~ /$s->[3]/) {
		$type = $s->[0];
		last;
		}
	}
return { 'id' => 0, 'desc' => $text{'this_server'}, 'type' => $type };
}

=head2 get_my_address

Returns the system's IP address, taken from eth0 or reverse resolution of
the hostname. Returns undef if this cannot be computed.

=cut
sub get_my_address
{
my $myip;
if (&foreign_check("net")) {
	# Try to get ethernet interface
	&foreign_require("net", "net-lib.pl");
	my @act = &net::active_interfaces();
	my @ifaces = grep { &net::iface_type($_->{'fullname'}) =~ /ether/i }
			  @act;
	@ifaces = ( $act[0] ) if (!@ifaces && @act);
	if (@ifaces) {
		return wantarray ? ( map { $_->{'address'} } @ifaces )
				 : $ifaces[0]->{'address'};
		}
	}
$myip = &to_ipaddress(&get_system_hostname());
if ($myip) {
	# Can resolve hostname .. use that
	return wantarray ? ( $myip ) : $myip;
	}
return wantarray ? ( ) : undef;
}

=head2 address_to_broadcast(address, net-mode)

Given an IP address, converts it to a broadcast by changing the last few
octets to 255.

=cut
sub address_to_broadcast
{
my $end = $_[1] ? "0" : "255";
my @ip = split(/\./, $_[0]);
return $ip[0] >= 192 ? "$ip[0].$ip[1].$ip[2].$end" :
       $ip[0] >= 128 ? "$ip[0].$ip[1].$end.$end" :
		       "$ip[0].$end.$end.$end";
}

=head2 test_server(host)

Returns undef if some server can be connected to OK, or an error message.

=cut
sub test_server
{
local $main::error_must_die = 1;
eval {
	$SIG{'ALRM'} = sub { die "Timeout\n" };
	alarm(10);
	&remote_foreign_require($_[0], "webmin", "webmin-lib.pl");
	alarm(0);
	};
my $rv = $@;
$rv =~ s/\s+at\s+(\S+)\s+line\s+\d+.*$//;
return $rv;
}

=head2 find_cron_job

Returns the cron job hash ref for the regular scheduled new servers check.

=cut
sub find_cron_job
{
&foreign_require("cron", "cron-lib.pl");
my ($job) = grep { $_->{'command'} eq $cron_cmd } &cron::list_cron_jobs();
return $job;
}

=head2 find_servers(&addresses, limit, no-print, defuser, defpass, deftype, &cluster-modules, find-self, port)

Attempts to find and register Webmin servers by sending out broadcast pings.
Mainly for internal use.

=cut
sub find_servers
{
my ($broad, $limit, $noprint, $defuser, $defpass, $deftype, $mods, $self,
    $port) = @_;
my (@found, @already, @foundme, %addmods);

my %server;
foreach my $s (&list_servers()) {
	$server{&to_ipaddress($s->{'host'})} = $s;
	$server{$s->{'host'}} = $s;
	}

# create the broadcast socket
my %miniserv;
&get_miniserv_config(\%miniserv);
$port ||= $config{'listen'} || $miniserv{'listen'} || 10000;
socket(BROAD, PF_INET, SOCK_DGRAM, getprotobyname("udp")) ||
	&error("socket failed : $!");
setsockopt(BROAD, SOL_SOCKET, SO_BROADCAST, pack("l", 1));

# Ignore primary IP address
my $myip = &get_my_address();
my %myaddr;
if ($myip && !$self) {
	$myaddr{inet_aton($myip)}++;
	}

# Find all our IPs
my %me = map { $_, 1 } &get_my_address();

# Ignore configured IPs
my %skip;
foreach my $skip (split(/\t+/, $config{'skipips'})) {
	$skip{&to_ipaddress($skip)} = 1;
	}

# Ignore our own IP addresses
if (&foreign_check("net")) {
	&foreign_require("net", "net-lib.pl");
	my @active = &net::active_interfaces();
	foreach my $a (@active) {
		if ($a->{'address'} && (!$self || $a->{'virtual'} ne '')) {
			$myaddr{inet_aton($a->{'address'})}++;
			}
		}

	# Adds IPs of interfaces to skip
	foreach my $skip (split(/\s+/, $config{'skipifaces'})) {
		my ($iface) = grep { $_->{'fullname'} eq $skip } @active;
		if ($iface) {
			$skip{$iface->{'address'}} = 1;
			}
		}
	}

# send out the packets
foreach my $b (&unique(@$broad)) {
	send(BROAD, "webmin", 0, pack_sockaddr_in($port, inet_aton($b)));
	}

my $id = time();
my $tmstart = time();
my $found;
my %already;
while(time()-$tmstart < $limit) {
	my $rin;
	vec($rin, fileno(BROAD), 1) = 1;
	if (select($rin, undef, undef, 1)) {
		my $buf;
		my $from = recv(BROAD, $buf, 1024, 0);
		next if (!$from);
		my ($fromport, $fromaddr) = unpack_sockaddr_in($from);
		my $fromip = inet_ntoa($fromaddr);
		if ($fromip !~ /\.(255|0)$/ && !$already{$fromip}++) {
			# Got a response .. parse it
			my ($host, $port, $ssl, $realhost) =split(/:/, $buf);
			if ($config{'resolve'}) {
				my $byname = gethostbyaddr($fromaddr,
							      AF_INET);
				$host = !$host && $byname ? $byname :
					!$host && !$byname ? $fromip :
							     $host;
				}
			else {
				$host = $fromip;
				}
			if ($host eq "0.0.0.0") {
				# Remote doesn't know it's IP or name
				my $byname = gethostbyaddr($fromaddr,
							      AF_INET);
				$host = $byname || $fromip;
				}
			my $url = ($ssl ? 'https' : 'http').
				     "://$host:$port/";

			# Hack for OC to use real hostname if we found
			# ourselves
			if ($config{'selfrealhost'} &&
			    $me{$fromip}) {
				$realhost = &get_system_hostname();
				}

			# See if we have already found this server
			if ($skip{$fromip}) {
				# On skip list
				print &text('find_skip',
				    "<tt>$url</tt>"),"<br>\n" if (!$noprint);
				}
			elsif ($server{$fromip}) {
				# Already got it (but update real hostname)
				print &text('find_already',
				    "<tt>$url</tt>"),"<br>\n" if (!$noprint);
				push(@already, $server{$fromip});
				if ($server{$fromip}->{'realhost'} ne $realhost) {
					$server{$fromip}->{'realhost'} = $realhost;
					&save_server($server{$fromip});
					}
				}
			elsif ($myaddr{$fromaddr}) {
				# This server
				print &text('find_me',
				    "<tt>$url</tt>"),"<br>\n" if (!$noprint);
				push(@foundme, $fromaddr);
				}
			elsif ($server{$host}) {
				# Already known server
				print &text('find_already2',
				    "<tt>$url</tt>"),"<br>\n" if (!$noprint);
				}
			else {
				# Found a new one!
				my $fast = $config{'deffast'} == 1 ? 1 : 0;
				my $serv = {	'id' => $id++,
						'ssl' => $ssl,
						'type' => $deftype || 'unknown',
					 	'fast' => $fast,
						'port' => $port,
						'host' => $host,
						'realhost' => $realhost,
						'user' => $defuser,
						'pass' => $defpass, };
				&save_server($serv);

				my $err;
				if ($defuser) {
					# See if the login was OK
					$err = &test_server($host);
					}
				if (!$noprint) {
					if ($err) {
						print &text('find_but',
						    "<tt>$url</tt>", $err),"<br>\n";
						}
					else {
						print &text('find_new',
							    "<tt>$url</tt>"),"<br>\n";
						}
					}
				push(@found, $serv);

				if ($defuser && !$err) {
					# Add in all the cluster modules too
					foreach my $m (@$mods) {
						&foreign_require($m, "$m-lib.pl");
						my ($ok, $out) = &foreign_call($m, "add_managed_host", $serv);
						push(@{$addmods{$serv->{'id'}}}, [ $m, $ok, $out ]);
						}
					}

				if ($defuser && !$err) {
					# Get the OS type
					if (&remote_foreign_check(
					     $serv, "servers")) {
						&remote_foreign_require(
							$serv, "servers",
							"servers-lib.pl");
						my $rt =
							&remote_foreign_call(
							$serv, "servers",
							"this_server");
						$serv->{'type'} = $rt->{'type'};
						&save_server($serv);
						}
					}

				&webmin_log("find", "server", $host, $serv);
				$server{$fromip} = $serv;
				}
			$found++;
			}
		}
	}
print "$text{'find_none'}<p>\n" if (!$found && !$noprint);
return ( \@found, \@already, \@foundme, \%addmods );
}

1;

