#!/usr/local/bin/perl
# create_virt.cgi
# Create a new virtual host.

require './apache-lib.pl';
&ReadParse();
$access{'create'} || &error($text{'cvirt_ecannot'});
&error_setup($text{'cvirt_err'});
$conf = &get_config();

# get directives from clone
if ($in{'clone'} ne '') {
	$clone = $conf->[$in{'clone'}];
	@cmems = grep { $_->{'name'} ne 'ServerName' &&
		        $_->{'name'} ne 'Port' &&
		        $_->{'name'} ne 'DocumentRoot' &&
		        $_->{'name'} ne 'ServerAlias' } @{$clone->{'members'}};
	}

# Parse and find the specified address to listen on
if ($in{'addr_def'} == 1) {
	if ($httpd_modules{'core'} >= 1.2) { $addr = "_default_"; }
	else { $addr = "*"; }
	}
elsif ($in{'addr_def'} == 2) {
	$addr = "*";
	}
elsif ($in{'addr'} !~ /\S/) {
	&error($text{'cvirt_eaddr1'});
	}
else {
	foreach $a (split(/\s+/, $in{'addr'})) {
		&to_ipaddress($a) || &to_ip6address($a) ||
			&error(&text('cvirt_eaddr2', $a));
		push(@addrs, &check_ip6address($a) ? "[$a]" : $a);
		}
	$addr = join(" ", @addrs);
	}

# Parse and find the specified port
$defport = &find_directive("Port", $conf) || 80;
if ($in{'port_mode'} == 0) {
	$port = "";
	$portnum = $defport;
	}
elsif ($in{'port_mode'} == 1) {
	$port = ":*";
	$portnum = "*";
	}
elsif ($in{'port'} !~ /^\d+$/) {
	&error(&text('cvirt_eport', $in{'port'}));
	}
else {
	$port = ":$in{'port'}";
	$portnum = $in{'port'};
	}

if (!$in{'name_def'}) {
	@names = split(/\s+/, $in{'name'});
	@names || &error(&text('cvirt_ename', $in{'name'}));
	foreach my $n (@names) {
		$n =~ /^[a-z0-9\.\_\-]+$/i || &error(&text('vserv_ename', $n));
		}
	}

# Check if the virtual server already exists
if (!$in{'name_def'}) {
	$aclname = "$in{'name'}$port";
	@virt = &find_directive_struct("VirtualHost", $conf);
	foreach $v (@virt) {
		local ($clash) = grep { $_ eq $aclname } &virt_acl_name($v);
		$clash && &error($text{'cvirt_etaken'});
		}
	}

# Check if the root directory is allowed
!$in{'root'} || &allowed_auth_file($in{'root'}) ||
	&error(&text('cvirt_eroot3', $in{'root'}));

if ($in{'root'} && !-e $in{'root'}) {
	# create the document root
	mkdir($in{'root'}, 0755) ||
		&error(&text('cvirt_eroot2', $in{'root'}, $!));
	$user = &find_directive("User", $conf);
	$group = &find_directive("Group", $conf);
	$user || &error($text{'cvirt_eroot4'});
	&set_ownership_permissions($user, $group, undef, $in{'root'});
	}

# find file to add to
if ($in{'fmode'} == 0) {
	# Use the first file in config (usually httpd.conf)
	$vconf = &get_virtual_config();
	$f = $vconf->[0]->{'file'};
	for($j=0; $vconf->[$j]->{'file'} eq $f; $j++) { }
	$l = $vconf->[$j-1]->{'eline'}+1;
	}
elsif ($in{'fmode'} == 1) {
	# Use the standard file/directory for virtual hosts
	local $vfile = &server_root($config{'virt_file'});
	if (!-d $vfile) {
		# Just appending to a file
		$f = $vfile;
		}
	elsif ($in{'name_def'}) {
		# No server name, so use webmin.UTIME.conf
		$linkfile = "webmin.".time().".conf";
		$f = "$vfile/$linkfile";
		}
	else {
		# Work out a filename
		$tmpl = $config{'virt_name'} || '${DOM}.conf';
		%hash = ( 'dom' => $in{'name'},
			  'ip' => $addr );
		$linkfile = &substitute_template($tmpl, \%hash);
		$f = "$vfile/$linkfile";
		}
	}
else {
	# Use a user-specified file
	$f = $in{'file'};
	}
-r $f || open(FILE, ">>$f") || &error(&text('cvirt_efile', &html_escape($f), $!));
close(FILE);

&lock_apache_files();
&lock_file($f);
&before_changing();
 
# Check each IP address for a needed Listen and NameVirtualHost directive
foreach $a (@addrs) {
	local $ip = &to_ipaddress($a);
	if ($in{'listen'} && $ip) {
		# add Listen on the IP if needed
		local @listen = &find_directive("Listen", $conf);
		local $lfound;
		foreach $l (@listen) {
			if ($portnum eq "*") {
				# Look for any Listen directive that would match the IP
				$lfound++ if ($l eq "*" ||
					      $l =~ /^\d+$/ ||
					      ($l =~ /^(\S+):(\d+)$/ &&
					       &to_ipaddress("$1") eq $ip) ||
					      &to_ipaddress($l) eq $ip);
				}
			else {
				# Look for a Listen directive that would match
				# the specified port and IP
				$lfound++ if (($l eq '*' && $portnum == $defport) ||
					      ($l =~ /^\*:(\d+)$/ && $portnum == $1) ||
					      ($l =~ /^0\.0\.0\.0:(\d+)$/ && $portnum == $1) ||
					      ($l =~ /^\d+$/ && $portnum == $l) ||
					      ($l =~ /^(\S+):(\d+)$/ &&
					       &to_ipaddress("$1") eq $ip &&
					       $2 == $portnum) ||
					      (&to_ipaddress($l) eq $ip));
				}
			}
		if (!$lfound && @listen > 0) {
			# Apache is listening on some IP addresses, but not the
			# entered one.
			local $lip;
			if ($httpd_modules{'core'} >= 2) {
				$lip = $in{'port_mode'} == 2 ? "$ip:$in{'port'}"
							     : "$ip:80";
				}
			else {
				$lip = $in{'port_mode'} == 2 ? "$ip:$in{'port'}" : $ip;
				}
			&save_directive("Listen", [ @listen, $lip ], $conf, $conf);
			}
		}

	# add NameVirtualHost if needed
	if ($in{'nv'} && !$in{'addr_def'} && $ip) {
		local $found;
		local @nv = &find_directive("NameVirtualHost", $conf);
		foreach $nv (@nv) {
			$found++ if (&to_ipaddress($nv) eq $ip ||
				     $nv =~ /^(\S+):(\S+)/ &&
				      &to_ipaddress("$1") eq $ip ||
				     $nv eq '*' ||
				     $nv =~ /^\*:(\d+)$/ && $1 eq $portnum ||
				     $nv =~ /^0\.0\.0\.0:(\d+)$/ && $1 eq $portnum);
			}
		if (!$found) {
			&save_directive("NameVirtualHost", [ @nv, $ip ], $conf, $conf);
			}
		}
	}

if ($in{'listen'} && $addr eq "*" && $portnum ne "*") {
	# Add Listen on the port if needed
	local @listen = &find_directive("Listen", $conf);
	local $lfound;
	foreach $l (@listen) {
		$lfound++ if ($l eq '*' && $portnum == $defport ||
			      &check_ipaddress($l) && $portnum == $defport ||
			      $l =~ /:(\d+)$/ && $portnum == $1 ||
			      $l =~ /^\d+$/ && $portnum == $l);
		}
	if (!$lfound && @listen > 0) {
		# Apache is not listening on the port for all IPs
		&save_directive("Listen", [ @listen, $portnum ], $conf, $conf);
		}
	}

# Create the structure
if (@addrs) {
	$ap = join(" ", map { $_.$port } @addrs);
	}
else {
	$ap = $addr.$port;
	}
@mems = ( );
$virt = { 'name' => 'VirtualHost',
	  'value' => $ap,
	  'file' => $f,
	  'type' => 1,
	  'members' => \@mems };
push(@mems, { 'name' => 'DocumentRoot',
	      'value' => "\"$in{'root'}\"" }) if ($in{'root'});
if (@names) {
	push(@mems, { 'name' => 'ServerName',
		      'value' => $names[0] });
	shift(@names);
	foreach $sa (@names) {
		push(@mems, { 'name' => 'ServerAlias',
			      'value' => $sa });
		}
	}
push(@mems, @cmems);

if ($in{'adddir'} && $in{'root'}) {
	# Add a <Directory> section for the root
	my @dmems;
	if ($httpd_modules{'core'} < 2.4) {
		push(@dmems, { 'name' => 'allow',
			       'value' => 'from all' });
		}
	push(@dmems, { 'name' => 'Options',
		       'value' => 'None' });
	$dirsect = { 'name' => 'Directory',
		     'value' => "\"$in{'root'}\"",
		     'type' => 1,
		     'members' => \@dmems,
		   };
	if ($httpd_modules{'core'} >= 2.4) {
		# Apache 2.4+ needs a 'Require all granted' line
		push(@{$dirsect->{'members'}},
		     { 'name' => 'Require',
		       'value' => 'all granted' });
		}
	push(@mems, $dirsect);
	}
foreach my $m (@mems) {
	$m->{'indent'} = 4;
	}
foreach my $m (@{$dirsect->{'members'}}) {
	$m->{'indent'} = 8;
	}

# Save to the file
&save_directive_struct(undef, $virt, $conf, $conf);
&flush_file_lines();
&unlock_file($f);
&update_last_config_change();
&unlock_apache_files();

# Create a symlink from another dir, if requested (as in Debian)
if ($linkfile) {
	&create_webfile_link($f);
	}

# Make sure it was really added
undef(@get_config_cache);
$conf = &get_config();
$found = 0;
foreach $v (&find_directive_struct("VirtualHost", $conf)) {
	next if ($v->{'value'} ne $ap);
	if (@names) {
		$nsn = &find_directive("ServerName", $v->{'members'});
		next if ($nsn ne $names[0]);
		}
	$found = 1;
	}
if (!$found) {
	&rollback_apache_config();
	&error(&text('cvirt_emissing', $f, "../config.cgi?$module_name"));
	}

&after_changing();
&format_config_file($f);
&webmin_log("virt", "create", ($in{'name_def'} ? $addr : $in{'name'}).$port,
	    \%in);

# add to acl
if ($access{'virts'} ne '*') {
	$access{'virts'} .= " $aclname";
	&save_module_acl(\%access);
	}
&redirect("");

