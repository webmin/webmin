#!/usr/local/bin/perl
# Update networking options

require './dovecot-lib.pl';
&ReadParse();
&error_setup($text{'net_err'});
$conf = &get_config();
&lock_dovecot_files($conf);

&save_directive($conf, "protocols", join(" ", split(/\0/, $in{'protocols'})));
$sslopt = &find("ssl_disable", $conf, 2) ? "ssl_disable" : "ssl";
&save_directive($conf, $sslopt, $in{$sslopt} eq '' ? undef : $in{$sslopt});
@listens = &find("imap_listen", $conf, 2) ?
		("imap_listen", "pop3_listen", "imaps_listen", "pop3s_listen") :
		("listen");
foreach $l (@listens) {
	if ($in{$l."_mode"} == 0) {
		$listen = undef;
		}
	elsif ($in{$l."_mode"} == 1) {
		$listen = "*, ::";
		}
	elsif ($in{$l."_mode"} == 2) {
		$listen = "*";
		}
	elsif ($in{$l."_mode"} == 4) {
		$listen = "::";
		}
	elsif ($in{$l."_mode"} == 3) {
		# Check each IP address
		my @ips_list = split(/[\s,]+/, $in{$l});
		my @ips_valid;
		my $has_ip4_wildcard = grep { $_ eq "*" } @ips_list;
		my $has_ip6_wildcard = grep { /^(\[::\]|::)$/ } @ips_list;
		foreach my $ip (@ips_list) {
			# Check for wildcards
			if ($ip =~ /^(\*|::|\[::\])$/) {
				push(@ips_valid, $ip);
				next;
				}
			
			# Validate IP address
			my $is_ipv4 = &check_ipaddress($ip);
			my $is_ipv6 = &check_ip6address($ip);
			if (!$is_ipv4 && !$is_ipv6) {
				&error(&text("net_ealisten", $ip));
				}

			# Add IP address to list
			push(@ips_valid, $ip);

			# Validate against wildcards
			&error(&text("net_ealisten_invalid_mix", $ip, "*"))
				if ($has_ip4_wildcard && &check_ipaddress($ip));
			&error(&text("net_ealisten_invalid_mix", $ip, "::"))
				if ($has_ip6_wildcard && &check_ip6address($ip));
			}
		$listen = join(", ", @ips_valid) if (@ips_valid);
		}
	&save_directive($conf, $l, $listen);
	}

&flush_file_lines();
&unlock_dovecot_files($conf);
&webmin_log("net");
&redirect("");

