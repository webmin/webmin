#!/usr/local/bin/perl
# stop.cgi
# Stop the mon process

require './mon-lib.pl';
&ReadParse();
if($in{'action_mon'}=~/$text{'mon_stop'}/){
	$out = &backquote_logged("/etc/init.d/mon stop 1>/dev/null 2>&1");
}elsif($in{'action_mon'}=~/$text{'mon_start'}/){
	$out = &backquote_logged("/etc/init.d/mon start 1>/dev/null 2>&1");
}else{
	$out = &backquote_logged("/etc/init.d/mon restart 1>/dev/null 2>&1");
}
&redirect("");

