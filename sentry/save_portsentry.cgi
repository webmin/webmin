#!/usr/local/bin/perl
# save_config.cgi
# Update the portsentry config file

require './sentry-lib.pl';
&ReadParse();
&error_setup($text{'portsentry_err'});
$conf = &get_portsentry_config();
&lock_config_files($conf);

# Validate and save inputs
@tports = split(/\s+/, $in{'tports'});
foreach $t (@tports) {
	$t > 0 && $t < 65535 || &error(&text('portsentry_etports', $t));
	}
&save_config($conf, "TCP_PORTS", join(",", @tports));
$in{'tadv'} > 0 && $in{'tadv'} < 65535 || &error($text{'portsentry_etadv'});
&save_config($conf, "ADVANCED_PORTS_TCP", $in{'tadv'});
@texc = split(/\s+/, $in{'texc'});
foreach $t (@texc) {
	$t > 0 && $t < 65535 || &error(&text('portsentry_etexc', $t));
	}
&save_config($conf, "ADVANCED_EXCLUDE_TCP", join(",", @texc));

@uports = split(/\s+/, $in{'uports'});
foreach $t (@uports) {
	$t > 0 && $t < 65535 || &error(&text('portsentry_euports', $t));
	}
&save_config($conf, "UDP_PORTS", join(",", @uports));
$in{'uadv'} > 0 && $in{'uadv'} < 65535 || &error($text{'portsentry_euadv'});
&save_config($conf, "ADVANCED_PORTS_UDP", $in{'uadv'});
@uexc = split(/\s+/, $in{'uexc'});
foreach $t (@uexc) {
	$t > 0 && $t < 65535 || &error(&text('portsentry_euexc', $t));
	}
&save_config($conf, "ADVANCED_EXCLUDE_UDP", join(",", @uexc));

&save_config($conf, "BLOCK_TCP", $in{'tblock'});
&save_config($conf, "BLOCK_UDP", $in{'ublock'});
&save_config($conf, "PORT_BANNER", $in{'banner'});

$in{'trigger'} =~ /^\d+$/ || &error($text{'portsentry_etrigger'});
&save_config($conf, "SCAN_TRIGGER", $in{'trigger'});

# Save list of ignored hosts
if (defined($in{'ignore'})) {
	if ($config{'portsentry_ignore'}) {
		$ign = $config{'portsentry_ignore'};
		}
	else {
		$ign = &find_value("IGNORE_FILE", $conf);
		}
	&lock_file($ign);
	$in{'ignore'} =~ s/\r//g;
	$in{'ignore'} =~ s/\n*$/\n/;
	foreach $h (split(/\s+/, $in{'ignore'})) {
		&to_ipaddress($h) ||
		  ($h =~ /^([0-9\.]+)\/(\d+)/ && &check_ipaddress($1)) ||
			&error(&text('portsentry_eignore', $h));
		}
	if (defined($in{'editbelow'})) {
		open(IGNORE, $ign);
		@below = <IGNORE>;
		close(IGNORE);
		@below = @below[$in{'editbelow'} .. $#below];
		}
	&open_tempfile(IGNORE, ">$ign");
	&print_tempfile(IGNORE, $in{'ignore'});
	&print_tempfile(IGNORE, @below);
	&close_tempfile(IGNORE);
	&unlock_file($ign);
	}
&flush_file_lines();
&unlock_config_files($conf);

if ($in{'apply'}) {
	# Restart portsentry
	&stop_portsentry();
	$err = &start_portsentry();
	&error($err) if ($err);
	}
&webmin_log("portsentry");

&redirect("");

