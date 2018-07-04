#!/usr/local/bin/perl
# switch_user.cgi
# Force the webserver to re-authenticate

BEGIN { push(@INC, "."); };
use WebminCore;

&init_config();
&get_miniserv_config(\%miniserv);
$id = $$.time();
open(LOGOUT, ">$miniserv{'logout'}$id");
printf LOGOUT "%d\n",
	$ENV{'HTTP_USER_AGENT'} =~ /(MSIE\s+[6321]\.)|(Netscape\/[4321])|(Lynx)|(Mozilla\/5.0)/ ? 1 : 2;
close(LOGOUT);
&redirect("/?miniserv_logout_id=$id");

