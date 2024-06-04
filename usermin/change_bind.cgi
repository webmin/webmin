#!/usr/local/bin/perl
# change_bind.cgi
# Update the binding IP address and port for miniserv

require './usermin-lib.pl';
$access{'bind'} || &error($text{'acl_ecannot'});
use Socket;
&ReadParse();
&get_usermin_miniserv_config(\%miniserv);
%oldminiserv = %miniserv;
&error_setup($text{'bind_err'});

# Validate inputs
for($i=0; defined($in{"ip_def_$i"}); $i++) {
	next if (!$in{"ip_def_$i"});
	if ($in{"ip_def_$i"} == 1) {
		$ip = "*";
		}
	else {
		$ip = $in{"ip_$i"};
		&check_ipaddress($ip) ||
		    $in{'ipv6'} && &check_ip6address($ip) ||
			&error(&text('bind_eip2', $ip));
		}
	if ($in{"port_def_$i"} == 1) {
		$port = $in{"port_$i"};
		$port =~ /^\d+$/ && $port < 65536 ||
			&error(&text('bind_eport2', $port));
		}
	else {
		$port = "*";
		}
	push(@sockets, [ $ip, $port ]);
	push(@ports, $port) if ($port && $port ne "*");
	}
@sockets || &error($text{'bind_enone'});
$in{'hostname_def'} || $in{'hostname'} =~ /^[a-z0-9\.\-]+$/i ||
	&error($text{'bind_ehostname'});
if ($in{'ipv6'}) {
	eval "use Socket6";
	$@ && &error(&text('bind_eipv6', "<tt>Socket6</tt>"));
	}

# For any new ports, check if they are already in use
@oldports = split(/\s+/, $in{'oldports'});
@newports = &unique(grep { &indexof($_, @oldports) < 0 } @ports);
if (&has_command("lsof")) {
        foreach my $p (@newports) {
                $out = &backquote_command("lsof -t -i tcp:$p 2>/dev/null");
                if ($out =~ /\d+/) {
                        &error(&text('bind_elsof', $p));
                        }
                }
        }

# Update config file
&lock_file($usermin_miniserv_config);
$first = shift(@sockets);
$miniserv{'port'} = $first->[1];
if ($first->[0] eq "*") {
	delete($miniserv{'bind'});
	}
else {
	$miniserv{'bind'} = $first->[0];
	}
$miniserv{'sockets'} = join(" ", map { "$_->[0]:$_->[1]" } @sockets);
if ($in{'websocket_base_port_def'}) {
	delete($miniserv{'websocket_base_port'});
	}
else {
	$miniserv{'websocket_base_port'} = $in{'websocket_base_port'};
	}
if ($in{'websocket_host_def'}) {
	delete($miniserv{'websocket_host'});
	}
else {
	$miniserv{'websocket_host'} = $in{'websocket_host'};
	}
$miniserv{'ipv6'} = $in{'ipv6'};
if ($in{'listen_def'}) {
	delete($miniserv{'listen'});
	}
else {
	$miniserv{'listen'} = $in{'listen'};
	}
if ($in{'hostname_def'}) {
	delete($miniserv{'host'});
	}
else {
	$miniserv{'host'} = $in{'hostname'};
	}
&put_usermin_miniserv_config(\%miniserv);
&unlock_file($usermin_miniserv_config);

# Attempt to re-start miniserv
$rv = &system_logged("$config{'usermin_dir'}/restart >/dev/null 2>&1 </dev/null");
if ($rv) {
	# Failed! Roll back config and start again
	&lock_file($usermin_miniserv_config);
	&put_usermin_miniserv_config(\%oldminiserv);
	&unlock_file($usermin_miniserv_config);
	&system_logged("$config{'usermin_dir'}/restart >/dev/null 2>&1 </dev/null");
	&error(&text('bind_erestart', $out));
	}

# If possible, open the new ports
foreach my $mod ("firewall", "firewalld") {
	if (&foreign_check($mod) && $in{'firewall'}) {
		if (@newports) {
			&clean_environment();
			$ENV{'WEBMIN_CONFIG'} = $config_directory;
			&system_logged(
				&module_root_directory($mod)."/open-ports.pl ".
			        join(" ", map { $_.":".($_+10) } @newports).
			        " >/dev/null 2>&1");
			&reset_environment();
			}
		}
	}

&webmin_log("bind", undef, undef, \%in);

&redirect("");

