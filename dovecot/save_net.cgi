#!/usr/local/bin/perl
# Update networking options

require './dovecot-lib.pl';
&ReadParse();
&error_setup($text{'net_err'});
&lock_file($config{'dovecot_config'});
$conf = &get_config();

&save_directive($conf, "protocols", join(" ", split(/\0/, $in{'protocols'})));
&save_directive($conf, "ssl_disable", $in{'ssl_disable'} eq '' ? undef : $in{'ssl_disable'});
@listens = &find("imap_listen", $conf, 2) ?
		("imap_listen", "pop3_listen", "imaps_listen", "pop3s_listen") :
		("listen", "ssl_listen");
foreach $l (@listens) {
	if ($in{$l."_mode"} == 0) {
		$listen = "";
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
&unlock_file($config{'dovecot_config'});
&webmin_log("net");
&redirect("");

