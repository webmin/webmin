#!/usr/local/bin/perl
# Update the list of TCP ports Sendmail uses

require './sendmail-lib.pl';
require './features-lib.pl';

&ReadParse();
&error_setup($text{'ports_err'});
$access{'ports'} || &error($text{'ports_ecannot'});

# Parse and validate inputs
@ports = ( );
if (!$in{'ports_def'}) {
	for($i=0; defined($name=$in{"name_$i"}); $i++) {
		# Port name
		next if (!$name);
		$name =~ /^[a-z0-9\_]+$/i || &error(&text('ports_ename', $i+1));
		$done{$name}++ && &error(&text('ports_eclash', $i+1));
		@opts = ( "Name=$name" );

		# IP address
		if (!$in{"addr_${i}_def"}) {
			&check_ipaddress($in{"addr_$i"}) ||
			   &check_ip6address($in{"addr_$i"}) ||
				&error(&text('ports_eaddr', $i+1));
			push(@opts, "Address=".$in{"addr_$i"});
			}

		# Family
		if ($in{"family_${i}"}) {
			push(@opts, "Family=".$in{"family_${i}"});
			}

		# TCP port
		if (!$in{"port_${i}_def"}) {
			$in{"port_$i"} =~ /^\d+$/ && $in{"port_$i"} > 0 &&
			    $in{"port_$i"} < 65536 ||
			    getservbyname($in{"port_$i"}, "tcp") ||
				&error(&text('ports_eport', $i+1));
			push(@opts, "Port=".$in{"port_$i"});
			}

		# Modifiers
		@mods = split(/\0/, $in{"mod_$i"});
		if (@mods) {
			push(@opts, "Modifiers=".join("", @mods));
			}

		# Other options
		push(@opts, split(/,/, $in{"other_$i"}));
		push(@ports, join(",", @opts));
		}
	}

# Update sendmail.cf
&lock_file($config{'sendmail_cf'});
$conf = &get_sendmailcf();
@oldlist = map { $_->[0] } &find_options("DaemonPortOptions", $conf);
@newlist = map { { 'type' => 'O',
		   'values' => [ " DaemonPortOptions=$_" ] } } @ports;
&save_directives($conf, \@oldlist, \@newlist);
&flush_file_lines($config{'sendmail_cf'});
&unlock_file($config{'sendmail_cf'});

# Update .mc file too, if we have one
if ($features_access) {
	@features = &list_features();
	if (@features) {
		&lock_file($config{'sendmail_mc'});
		@dpa = grep { $_->{'type'} == 0 &&
			$_->{'text'} =~ /^DAEMON_OPTIONS/ } @features;
		for($i=0; $i<@dpa || $i<@ports; $i++) {
			if ($dpa[$i] && $ports[$i]) {
				# Modify
				$dpa[$i]->{'text'} =
					"DAEMON_OPTIONS(`$ports[$i]')";
				&modify_feature($dpa[$i]);
				}
			elsif ($dpa[$i] && !$ports[$i]) {
				# No longer needed .. delete
				&delete_feature($dpa[$i]);
				}
			elsif (!$dpa[$i] && $ports[$i]) {
				# Add new feature
				$f = { 'type' => 0,
			           'text' => "DAEMON_OPTIONS(`$ports[$i]')" };
				&create_feature($f);
				}
			}
		&unlock_file($config{'sendmail_mc'});
		}
	}

# Restart Sendmail
&restart_sendmail();
&webmin_log("ports");
&redirect("");

