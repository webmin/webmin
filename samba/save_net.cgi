#!/usr/local/bin/perl
# save_net.cgi
# Save inputs from conf_net.cgi

require './samba-lib.pl';
&ReadParse();
&lock_file($config{'smb_conf'});
$global = &get_share("global");

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcn'}") unless $access{'conf_net'};

&error_setup($text{'savenet_fail'});
if (!$in{dead_time_def} && $in{dead_time} !~ /^\d+$/) {
	&error(&text('savenet_timeout', $in{dead_time}));
	}
&setval("deadtime", $in{dead_time_def} ? 0 : $in{dead_time}, 0);

&setval("hosts equiv", $in{hosts_equiv_def} ? "" : $in{hosts_equiv}, "");

if ($in{interfaces_def}) { &delval("interfaces"); }
else {
	for($i=0; defined($in{"interface_ip$i"}); $i++) {
		next if (!$in{"interface_ip$i"});
		if ($in{"interface_nm$i"}) {
			push(@ifaces, $in{"interface_ip$i"}."/".
				      $in{"interface_nm$i"});
			}
		else {
			push(@ifaces, $in{"interface_ip$i"});
			}
		}
	&setval("interfaces", join(' ', @ifaces), "");
	}

if (!$in{keepalive_def} && $in{keepalive} !~ /^\d+$/) {
	&error(&text('savenet_keep', $in{keepalive}));
	}
&setval("keepalive", $in{keepalive_def} ? 0 : $in{keepalive}, 0);

if (!$in{max_xmit_def} && $in{max_xmit} !~ /^\d+$/) {
	&error(&text('savenet_maxxmit', $in{max_xmit}));
	}
&setval("max xmit", $in{max_xmit_def} ? 0 : $in{max_xmit}, 0);

&setval("socket address",
	$in{socket_address_def} ? "" : $in{socket_address}, "");

foreach (@sock_opts) {
	/^([A-Z\_]+)(.*)$/;
	if ($2 eq "*") {
		if ($in{$1}) { push(@sopts, "$1=".$in{"$1_val"}); }
		}
	else {
		if ($in{$1}) { push(@sopts, $1); }
		}
	}
&setval("socket options", join(' ',@sopts), "");

if ($global) { &modify_share("global", "global"); }
else { &create_share("global"); }
&unlock_file($config{'smb_conf'});
&webmin_log("net", undef, undef, \%in);
&redirect("");

