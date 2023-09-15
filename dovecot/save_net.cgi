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
		("listen", "ssl_listen");
foreach $l (@listens) {
	if ($in{$l."_mode"} == 0) {
		$listen = undef;
		}
	elsif ($in{$l."_mode"} == 1) {
		$listen = "[::]";
		}
	elsif ($in{$l."_mode"} == 2) {
		$listen = "*";
		}
	elsif ($in{$l."_mode"} == 3) {
		&check_ipaddress($in{$l}) || &error($text{'net_e'.$l});
		$listen = $in{$l};
		}
	&save_directive($conf, $l, $listen);
	}

&flush_file_lines();
&unlock_dovecot_files($conf);
&webmin_log("net");
&redirect("");

