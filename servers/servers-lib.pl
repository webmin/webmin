# servers-lib.pl
# Common functions for managing servers

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
%access = &get_module_acl();
$cron_cmd = "$module_config_directory/auto.pl";

@cluster_modules = ( "cluster-software" );

sub list_servers
{
local ($f, @rv);
opendir(DIR, $module_config_directory);
while($f = readdir(DIR)) {
	if ($f =~ /^(\d+)\.serv$/) {
		push(@rv, &get_server($1));
		}
	}
closedir(DIR);
return @rv;
}

# list_servers_sorted(applyacl)
# Returns a list of servers, sorted according to the module configuration
sub list_servers_sorted
{
local @servers = &list_servers();
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

# get_server(id)
sub get_server
{
local $serv;
$serv->{'id'} = $_[0];
&read_file("$module_config_directory/$_[0].serv", $serv) || return undef;
return $serv;
}

# save_server(&server)
sub save_server
{
&lock_file("$module_config_directory/$_[0]->{'id'}.serv");
&write_file("$module_config_directory/$_[0]->{'id'}.serv", $_[0]);
chmod(0600, "$module_config_directory/$_[0]->{'id'}.serv");
&unlock_file("$module_config_directory/$_[0]->{'id'}.serv");
undef(%main::remote_servers_cache);
}

# delete_server(id)
sub delete_server
{
&lock_file("$module_config_directory/$_[0].serv");
unlink("$module_config_directory/$_[0].serv");
&unlock_file("$module_config_directory/$_[0].serv");
undef(%main::remote_servers_cache);
}

# can_use_server(&server)
sub can_use_server
{
return 1 if ($access{'servers'} eq '*');
foreach $s (split(/\s+/, $access{'servers'})) {
	return 1 if ($_[0]->{'host'} eq $s ||
		     $_[0]->{'id'} eq $s);
	}
return 0;
}

# list_all_groups([&servers])
# Returns a list of all webmin and MSC groups and their members
sub list_all_groups
{
local (@rv, %gmap, $s, $f, $gn);

# Add webmin servers groups
foreach $s ($_[0] ? @{$_[0]} : &list_servers()) {
	foreach $gn (split(/\t+/, $s->{'group'})) {
		local $grp = $gmap{$gn};
		if (!$grp) {
			$gmap{$gn} = $grp = { 'name' => $gn, 'type' => 0 };
			push(@rv, $grp);
			}
		push(@{$grp->{'members'}}, $s->{'host'});
		}
	}

# Add MSC cluster groups
opendir(DIR, $config{'groups_dir'});
foreach $f (readdir(DIR)) {
	next if ($f eq '.' || $f eq '..');
	local $grp = $gmap{$f};
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
			push(@{$grp->{'members'}}, map { $1.$_.$4 } ($2 .. $3));
			}
		elsif (/(\S+)/) {
			push(@{$grp->{'members'}}, $1);
			}
		}
	close(GROUP);
	}
closedir(DIR);

# Fix up MSC groups that include other groups
while(1) {
	local ($grp, $any);
	foreach $grp (@rv) {
		local @mems;
		foreach $m (@{$grp->{'members'}}) {
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

# logged_in(&serv)
sub logged_in
{
local $id = $_[0]->{'id'};
if ($ENV{'HTTP_COOKIE'} =~ /$id=([A-Za-z0-9=]+)/) {
	return split(/:/, &decode_base64("$1"));
	}
else {
	return ();
	}
}

@server_types = (
		  [ 'asianux', 'Asianux', undef, 'Asianux' ],
		  [ 'centos', 'CentOS Linux', undef, 'CentOS' ],
		  [ 'cobalt', 'Cobalt Linux', 'cobalt-linux' ],
		  [ 'debian', 'Debian Linux', 'debian-linux' ],
		  [ 'fedora', 'Fedora Linux', undef, 'Fedora' ],
		  [ 'caldera', 'OpenLinux', 'open-linux' ],
		  [ 'mandrake', 'Mandrake Linux', 'mandrake-linux' ],
		  [ 'msc', 'MSC.Linux', 'msc-linux' ],
		  [ 'redhat', 'Redhat Linux', 'redhat-linux' ],
		  [ 'redflag', 'Red Flag Linux', undef, 'RedFlag' ],
		  [ 'slackware', 'Slackware Linux', 'slackware-linux' ],
		  [ 'suse', 'SuSE Linux', 'suse-linux' ],
		  [ 'turbo', 'TurboLinux', 'turbo-linux' ],
		  [ 'ubuntu', 'Ubuntu Linux', undef, 'Ubuntu' ],
		  [ 'linux', 'Linux', '.*-linux' ],

		  [ 'freebsd', 'FreeBSD', 'freebsd' ],
		  [ 'solaris', 'Solaris', 'solaris' ],
		  [ 'hpux', 'HP/UX', 'hpux' ],
		  [ 'sco', 'SCO', '(openserver|unixware)' ],
		  [ 'mac', 'Macintosh', 'macos' ],
		  [ 'irix', 'IRIX', 'irix' ],
		  [ 'windows', 'Windows', 'windows' ],
		  [ 'unknown', $text{'lib_other'} ] );

# this_server()
# Returns a fake servers-list entry for this server
sub this_server
{
local $type = 'unknown';
foreach $s (@server_types) {
	if ($s->[2] && $gconfig{'os_type'} =~ /^$s->[2]$/ ||
	    $s->[3] && $gconfig{'real_os_type'} =~ /$s->[3]/) {
		$type = $s->[0];
		last;
		}
	}
return { 'id' => 0, 'desc' => $text{'this_server'}, 'type' => $type };
}

# get_my_address()
# Returns the system's IP address, or undef
sub get_my_address
{
local $myip;
if (&foreign_check("net")) {
	# Try to get ethernet interface
	&foreign_require("net", "net-lib.pl");
	local @act = &net::active_interfaces();
	local @ifaces = grep { &net::iface_type($_->{'fullname'}) =~ /ether/i }
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

# address_to_broadcast(address, net-mode)
sub address_to_broadcast
{
local $end = $_[1] ? "0" : "255";
local @ip = split(/\./, $_[0]);
return $ip[0] >= 192 ? "$ip[0].$ip[1].$ip[2].$end" :
       $ip[0] >= 128 ? "$ip[0].$ip[1].$end.$end" :
		       "$ip[0].$end.$end.$end";
}

# test_server(host)
# Returns undef if some server can be connected to OK, or an error message
sub test_server
{
local $main::error_must_die = 1;
eval {
	$SIG{'ALRM'} = sub { die "Timeout\n" };
	alarm(10);
	&remote_foreign_require($_[0], "webmin", "webmin-lib.pl");
	alarm(0);
	};
local $rv = $@;
$rv =~ s/\s+at\s+(\S+)\s+line\s+\d+.*$//;
return $rv;
}

sub find_cron_job
{
&foreign_require("cron", "cron-lib.pl");
local ($job) = grep { $_->{'command'} eq $cron_cmd } &cron::list_cron_jobs();
return $job;
}

# find_servers(&addresses, limit, no-print, defuser, defpass, deftype,
#	       &cluster-modules, find-self, port)
sub find_servers
{
local ($broad, $limit, $noprint, $defuser, $defpass, $deftype, $mods, $self,
       $port) = @_;
local (@found, @already, @foundme, %addmods);

my %server;
foreach my $s (&list_servers()) {
	$server{&to_ipaddress($s->{'host'})} = $s;
	}

# create the broadcast socket
local %miniserv;
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
local %skip;
foreach my $skip (split(/\t+/, $config{'skipips'})) {
	$skip{&to_ipaddress($skip)} = 1;
	}

# Ignore our own IP addresses
if (&foreign_check("net")) {
	&foreign_require("net", "net-lib.pl");
	local @active = &net::active_interfaces();
	foreach my $a (@active) {
		if ($a->{'address'} && (!$self || $a->{'virtual'} ne '')) {
			$myaddr{inet_aton($a->{'address'})}++;
			}
		}

	# Adds IPs of interfaces to skip
	foreach my $skip (split(/\s+/, $config{'skipifaces'})) {
		local ($iface) = grep { $_->{'fullname'} eq $skip } @active;
		if ($iface) {
			$skip{$iface->{'address'}} = 1;
			}
		}
	}

# send out the packets
@broad = &unique(@broad);
foreach my $b (@broad) {
	send(BROAD, "webmin", 0, pack_sockaddr_in($port, inet_aton($b)));
	}

my $id = time();
my $tmstart = time();
my $found;
my %already;
while(time()-$tmstart < $limit) {
	local $rin;
	vec($rin, fileno(BROAD), 1) = 1;
	if (select($rin, undef, undef, 1)) {
		local $buf;
		local $from = recv(BROAD, $buf, 1024, 0);
		next if (!$from);
		local ($fromport, $fromaddr) = unpack_sockaddr_in($from);
		local $fromip = inet_ntoa($fromaddr);
		if ($fromip !~ /\.(255|0)$/ && !$already{$fromip}++) {
			# Got a response .. parse it
			local ($host, $port, $ssl, $realhost) =split(/:/, $buf);
			if ($config{'resolve'}) {
				local $byname = gethostbyaddr($fromaddr,
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
				local $byname = gethostbyaddr($fromaddr,
							      AF_INET);
				$host = $byname || $fromip;
				}
			local $url = ($ssl ? 'https' : 'http').
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
			else {
				# Found a new one!
				local $fast = $config{'deffast'} == 1 ? 1 : 0;
				local $serv = {	'id' => $id++,
						'ssl' => $ssl,
						'type' => $deftype || 'unknown',
					 	'fast' => $fast,
						'port' => $port,
						'host' => $host,
						'realhost' => $realhost,
						'user' => $defuser,
						'pass' => $defpass, };
				&save_server($serv);

				local $err;
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
						($ok, $out) = &foreign_call($m, "add_managed_host", $serv);
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
						local $rt =
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

