#!/usr/local/bin/perl
# change_bind.cgi
# Update the binding IP address and port for miniserv

require './webmin-lib.pl';
&ReadParse();
&get_miniserv_config(\%miniserv);
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
$in{'listen_def'} || $in{'listen'} =~ /^\d+$/ || &error($text{'bind_elisten'});
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

# Make sure each IP is actually active on the system
@ips = grep { $_ ne "*" } map { $_->[0] } @sockets;
if (@ips && &foreign_installed("net")) {
	%onsystem = ( );
	&foreign_require("net");
	if (defined(&net::active_interfaces)) {
		foreach $a (&net::active_interfaces()) {
			$onsystem{$a->{'address'}} = $a;
			foreach $ip6 (@{$a->{'address6'}}) {
				$onsystem{&canonicalize_ip6($ip6)} = $a;
				}
			}
		}
	if (%onsystem) {
		foreach $ip (@ips) {
			$onsystem{&canonicalize_ip6($ip)} ||
				&error(&text('bind_eonsystem', $ip));
			}
		}
	}

# Update config file
&lock_file($ENV{'MINISERV_CONFIG'});
$first = shift(@sockets);
$miniserv{'port'} = $first->[1];
if ($first->[0] eq "*") {
	delete($miniserv{'bind'});
	}
else {
	$miniserv{'bind'} = $first->[0];
	}
$miniserv{'sockets'} = join(" ", map { "$_->[0]:$_->[1]" } @sockets);
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
$miniserv{'no_resolv_myname'} = $in{'no_resolv_myname'};
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});

# Attempt to re-start miniserv
$SIG{'TERM'} = 'ignore';
&system_logged("$config_directory/stop >/dev/null 2>&1 </dev/null");
$temp = &transname();
$rv = &system_logged("$config_directory/start >$temp 2>&1 </dev/null");
$out = &read_file_contents($temp);
$out =~ s/^Starting Webmin server in.*\n//;
$out =~ s/at.*line.*//;
unlink($temp);
if ($rv) {
	# Failed! Roll back config and start again
	&lock_file($ENV{'MINISERV_CONFIG'});
	&put_miniserv_config(\%oldminiserv);
	&unlock_file($ENV{'MINISERV_CONFIG'});
	&system_logged("$config_directory/start >/dev/null 2>&1 </dev/null");
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

# Work out redirect URL
if ($miniserv{'musthost'}) { $miniserv{'musthost'}; }
elsif ($miniserv{'bind'}) { $url = $miniserv{'bind'}; }
else { $url = $ENV{'SERVER_NAME'}; }
if ($ENV{'HTTPS'} eq "ON") { $url = "https://$url"; }
else { $url = "http://$url"; }

if ($tconfig{'inframe'}) {
	# Theme uses frames, so we need to redirect the whole frameset
	$url .= ":$miniserv{'port'}";
	&ui_print_header(undef, $text{'bind_title'}, "");
	print $text{'bind_redirecting'},"<p>\n";
	print "<script>\n";
	print "top.location = '$url';\n";
	print "</script>\n";
	&ui_print_footer("", $text{'index_return'});
	}
else {
	$url .= ":$miniserv{'port'}/webmin/";
	&redirect($url);
	}

