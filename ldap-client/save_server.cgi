#!/usr/local/bin/perl
# Save the LDAP server to connect to

require './ldap-client-lib.pl';
&error_setup($text{'server_err'});
&ReadParse();

&lock_file(&get_ldap_config_file());
@secrets = split(/\t+/, $config{'secret'});
foreach $secret (@secrets) {
	&lock_file($secret);
	}
$conf = &get_config();
$uri = &find_svalue("uri", $conf);

# Validate and save inputs
if ($uri) {
	# Save uri directive
	for($i=0; defined($host = $in{'uhost_'.$i}); $i++) {
		next if (!$host);
		$port = $in{'uport_'.$i.'_def'} ? undef : $in{'uport_'.$i};
		$proto = $in{'uproto_'.$i};
		!defined($port) ||
		    $port =~ /^\d+$/ && $port > 0 && $port < 65536 ||
		    &error(&text('server_euport', $host));
		$uri = $proto."://".$host.($port ? ":$port" : "");
		$uri .= "/" if ($proto eq "ldap" || $proto eq "ldaps");
		push(@uris, $uri);
		}
	@uris || &error($text{'server_euri'});
	&save_directive($conf, "uri", join(" ", @uris));
	}
else {
	# Set host and port directives
	@hosts = split(/\s+/, $in{'host'});
	foreach $h (@hosts) {
		&to_ipaddress($h) || &to_ip6address($h) ||
			&error(&text('server_ehost', $h));
		}
	@hosts || &error($text{'server_ehosts'});
	&save_directive($conf, "host", join(" ", @hosts));

	# Save server port
	if ($in{'port_def'}) {
		&save_directive($conf, "port", undef);
		}
	else {
		$in{'port'} =~ /^\d+$/ &&
		    $in{'port'} > 0 && $in{'port'} < 65536 ||
			&error($text{'server_eport'});
		&save_directive($conf, "port", $in{'port'});
		}
	}

# Save LDAP protocol version
&save_directive($conf, "ldap_version", $in{'version'} || undef);

# Save time limit
if ($in{'timelimit_def'}) {
	&save_directive($conf, "bind_timelimit", undef);
	}
else {
	$in{'timelimit'} =~ /^\d+$/ || &error($text{'server_etimelimit'});
	&save_directive($conf, "bind_timelimit", $in{'timelimit'});
	}

# Save non-root login
if ($in{'binddn_def'}) {
	&save_directive($conf, "binddn", undef);
	}
else {
	$in{'binddn'} =~ /\S/ || &error($text{'server_ebinddn'});
	&save_directive($conf, "binddn", $in{'binddn'});
	}

# Save non-root password
if ($in{'bindpw_def'}) {
	&save_directive($conf, "bindpw", undef);
	}
else {
	$in{'bindpw'} =~ /\S/ || &error($text{'server_ebindpw'});
	&save_directive($conf, "bindpw", $in{'bindpw'});
	}

# Save root login
my $rootdir = &find_svalue("rootpwmoddn", $conf, 2) ?
		"rootpwmoddn" : "rootbinddn";
if ($in{'rootbinddn_def'}) {
	&save_directive($conf, $rootdir, undef);
	}
else {
	$in{'rootbinddn'} =~ /\S/ || &error($text{'server_erootbinddn'});
	&save_directive($conf, $rootdir, $in{'rootbinddn'});
	}

# Save root password
$in{'rootbindpw_def'} || $in{'rootbindpw'} =~ /\S/ ||
	&error($text{'server_erootbindpw'});
if (&find_svalue("rootpwmoddn", $conf), 2) {
	# New format can put the password in the config file
	&save_directive($conf, "rootpwmodpw",
		$in{'rootbindpw_def'} ? undef : $in{'rootbindpw'});
	}
else {
	# Old format uses a separate secret file
	if ($in{'rootbindpw_def'}) {
		&save_rootbinddn_secret(undef);
		}
	else {
		&save_rootbinddn_secret($in{'rootbindpw'});
		}
	}

# SSL mode
if (defined($in{'ssl'})) {
	&save_directive($conf, "ssl", $in{'ssl'} || undef);
	}

# Check server SSL cert
&save_directive($conf, "tls_checkpeer", $in{'peer'} || undef);

# CA cert file for server
if ($in{'cacert_def'}) {
	&save_directive($conf, "tls_cacertfile", undef);
	}
else {
	$in{'cacert'} =~ /^\// && -r $in{'cacert'} && !-d $in{'cacert'} ||
		&error($text{'server_ecacert'});
	&save_directive($conf, "tls_cacertfile", $in{'cacert'});
	}

# Write out config
&flush_file_lines();
&unlock_file(&get_ldap_config_file());
foreach $secret (@secrets) {
	&unlock_file($secret);
	}

&webmin_log("server");
&redirect("");

