#!/usr/local/bin/perl
# delete_rpc.cgi
# Delete an RPC program

require './inetd-lib.pl';
&ReadParse();

&lock_inetd_files();
@rpcs = &list_rpcs();
@rpc = @{$rpcs[$in{'rpos'}]};
&delete_rpc($rpc[0]);
if ($in{'ipos'} =~ /\d/) {
	@inets = &list_inets();
	@inet = @{$inets[$in{'ipos'}]};
	&delete_inet($inet[0], $inet[10]);
	}
&unlock_inetd_files();
&webmin_log("delete", "rpc", $rpc[1],
	    { 'name' => $rpc[1], 'number' => $rpc[2],
	      'active' => $inet[1],
	      'user' => $inet[7], 'wait' => $inet[6],
	      'prog' => join(" ", @inet[8..@inet-1]) } );
&redirect("");
