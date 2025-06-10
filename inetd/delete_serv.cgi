#!/usr/local/bin/perl
# delete_inet.cgi
# Delete an internet service

require './inetd-lib.pl';
&ReadParse();

&lock_inetd_files();
@servs = &list_services();
@serv = @{$servs[$in{'spos'}]};
&delete_service($serv[0]);
if ($in{'ipos'} =~ /\d/) {
	@inets = &list_inets();
	@inet = @{$inets[$in{'ipos'}]};
	&delete_inet($inet[0], $inet[10]);
	}
&unlock_inetd_files();
&webmin_log("delete", "serv", $serv[1],
	    { 'name' => $serv[1], 'port' => $serv[2],
	      'proto' => $serv[3], 'active' => $inet[1],
	      'user' => $inet[7], 'wait' => $inet[6],
	      'prog' => join(" ", @inet[8..@inet-1]) } );
&redirect("");

