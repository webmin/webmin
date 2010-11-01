#!/usr/local/bin/perl
# save_host.cgi
# Create, update or delete a client host

require (-r 'sshd-lib.pl' ? './sshd-lib.pl' : './ssh-lib.pl');
&ReadParse();
&lock_file($config{'client_config'});
$hconf = &get_client_config();
&error_setup($text{'host_err'});

# Get version and type
if (&get_product_name() eq 'usermin') {
	$version_type = &get_ssh_type();
	$version_number = &get_ssh_version();
	}
else {
	$version_type = $version{'type'};
	$version_number = $version{'number'};
	}

if ($in{'delete'}) {
	# Just delete the host
	$host = $hconf->[$in{'idx'}];
	&delete_host($host);
	}
else {
	# Saving or creating a host
	$host = $hconf->[$in{'idx'}] if (!$in{'new'});
	if ($in{'name_def'}) {
		$host->{'values'} = [ '*' ];
		}
	else {
		$in{'name'} =~ /^\S+$/ || &error($text{'host_ename'});
		$host->{'values'} = [ $in{'name'} ];
		}
	if ($in{'new'}) {
		# Create empty host structure
		&create_host($host);
		}
	else {
		&modify_host($host);
		}
	$conf = $host->{'members'};

	# Validate and store host options
	if ($in{'user_def'}) {
		&save_directive("User", $conf);
		}
	else {
		$in{'user'} =~ /^\S+$/ || &error($text{'host_euser'});
		&save_directive("User", $conf, $in{'user'});
		}

	&save_directive("KeepAlive", $conf,
		$in{'keep'} == 2 ? undef : $in{'keep'} ? 'yes' : 'no');

	if ($in{'hostname_def'}) {
		&save_directive("HostName", $conf);
		}
	else {
		&to_ipaddress($in{'hostname'}) ||
		    &to_ip6address($in{'hostname'}) ||
			&error($text{'host_ehostname'});
		&save_directive("HostName", $conf, $in{'hostname'});
		}

	&save_directive("BatchMode", $conf,
		$in{'batch'} == 2 ? undef : $in{'batch'} ? 'yes' : 'no');

	if ($in{'port_def'}) {
		&save_directive("Port", $conf);
		}
	else {
		$in{'port'} =~ /^\d+$/ || &error($text{'host_eport'});
		&save_directive("Port", $conf, $in{'port'});
		}

	if ($version_type ne 'ssh' || $version_number < 3) {
		&save_directive("Compression", $conf,
			$in{'comp'} == 2 ? undef : $in{'comp'} ? 'yes' : 'no');
		}

	if ($in{'escape_def'} == 1) {
		&save_directive("EscapeChar", $conf);
		}
	elsif ($in{'escape_def'} == 2) {
		&save_directive("EscapeChar", $conf, "none");
		}
	else {
		$in{'escape'} =~ /^\S$/ || $in{'escape'} =~ /^\^\S$/ ||
			 &error($text{'host_eescape'});
		&save_directive("EscapeChar", $conf, $in{'escape'});
		}

	
	if ($version_type ne 'ssh' || $version_number < 3) {
		if ($in{'clevel_def'}) {
			&save_directive("CompressionLevel", $conf);
			}
		else {
			&save_directive("CompressionLevel", $conf,
					$in{'clevel'});
			}

		if ($in{'attempts_def'}) {
			&save_directive("ConnectionAttempts", $conf);
			}
		else {
			$in{'attempts'} =~ /^\d+$/ ||
				&error($text{'host_eattempts'});
			&save_directive("ConnectionAttempts", $conf,
					$in{'attempts'});
			}

		&save_directive("UsePrivilegedPort", $conf,
			$in{'priv'} == 2 ? undef : $in{'priv'} ? 'yes' : 'no');

		&save_directive("FallBackToRsh", $conf,
			$in{'rsh'} == 2 ? undef : $in{'rsh'} ? 'yes' : 'no');

		&save_directive("UseRsh", $conf,
		    $in{'usersh'} == 2 ? undef : $in{'usersh'} ? 'yes' : 'no');
		}

	&save_directive("ForwardAgent", $conf,
		$in{'agent'} == 2 ? undef : $in{'agent'} ? 'yes' : 'no');

	&save_directive("ForwardX11", $conf,
		$in{'x11'} == 2 ? undef : $in{'x11'} ? 'yes' : 'no');

	&save_directive("StrictHostKeyChecking", $conf,
		$in{'strict'} == 2 ? undef : $in{'strict'} == 1 ? 'yes' :
		$in{'strict'} == 0 ? 'no' : 'ask');

	if ($version_type eq 'openssh') {
		&save_directive("CheckHostIP", $conf,
		  $in{'checkip'} == 2 ? undef : $in{'checkip'} ? 'yes' : 'no');

		&save_directive("Protocol", $conf, $in{'prots'} || undef);
		}

	for($i=0; defined($in{"llport_$i"}); $i++) {
		next if (!$in{"llport_$i"} && !$in{"lrhost_$i"} &&
			 !$in{"lrport_$i"});
		$in{"llport_$i"} =~ /^\d+$/ || &error($text{'host_elport'});
		$in{"lrhost_$i"} =~ /^\S+$/ || &error($text{'host_erhost'});
		$in{"lrport_$i"} =~ /^\d+$/ || &error($text{'host_erport'});
		push(@lforward, sprintf("%d %s:%d", $in{"llport_$i"},
				 	$in{"lrhost_$i"}, $in{"lrport_$i"}));
		}
	&save_directive("LocalForward", $conf, @lforward);

	for($i=0; defined($in{"rrport_$i"}); $i++) {
		next if (!$in{"rrport_$i"} && !$in{"rlhost_$i"} &&
			 !$in{"rlport_$i"});
		$in{"rrport_$i"} =~ /^\d+$/ || &error($text{'host_erport'});
		$in{"rlhost_$i"} =~ /^\S+$/ || &error($text{'host_elhost'});
		$in{"rlport_$i"} =~ /^\d+$/ || &error($text{'host_elport'});
		push(@rforward, sprintf("%d %s:%d", $in{"rrport_$i"},
				 	$in{"rlhost_$i"}, $in{"rlport_$i"}));
		}
	&save_directive("RemoteForward", $conf, @rforward);
	}

&flush_file_lines();
&unlock_file($config{'client_config'});
if (&get_product_name() ne 'usermin') {
	&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "update",
		    "host", $host->{'values'}->[0]);
	}
&redirect("list_hosts.cgi");

