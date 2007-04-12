#!/usr/local/bin/perl
# save_security.cgi
# Save NIS server security options

require './nis-lib.pl';
&ReadParse();
&error_setup($text{'security_err'});

# Save trusted servers
if ($config{'securenets'}) {
	for($i=0; defined($in{"net_$i"}); $i++) {
		next if ($in{"def_$i"} == -1);
		if ($in{"def_$i"} == 0) {
			&check_ipaddress($in{"net_$i"}) ||
				&error(&text('security_enet', $in{"net_$i"}));
			&check_ipaddress($in{"mask_$i"}) ||
				&error(&text('security_emask', $in{"mask_$i"}));
			$mask = $in{"mask_$i"};
			}
		elsif ($in{"def_$i"} == 1) {
			&check_ipaddress($in{"net_$i"}) ||
				&error(&text('security_enet', $in{"net_$i"}));
			$mask = "host";
			}
		elsif ($in{"def_$i"} == 2) {
			$in{"net_$i"} = "0.0.0.0";
			$mask = "0.0.0.0";
			}
		push(@lines, $mask." ".$in{"net_$i"}."\n");
		}
	&open_tempfile(SERVERS, ">$config{'securenets'}");
	&print_tempfile(SERVERS, @lines);
	&close_tempfile(SERVERS);
	}

# Save OS-specific security options
&parse_server_security();

&redirect("");

