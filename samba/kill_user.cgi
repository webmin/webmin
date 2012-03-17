#!/usr/local/bin/perl
# kill_user.cgi
# Kill a samba process connecting to some client

require './samba-lib.pl';
&ReadParse();

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
if ($in{share}) { # this may be cracked very easy, don't know how to do better :(
	# per-share acls ...
	&error("$text{'eacl_np'} $text{'eacl_pkill'}") 
		unless &can('rvV',\%access, $in{share}); # read, view conn, kill conn
	}
else {
	&error("$text{'eacl_np'} $text{'eacl_pgkill'}") 
		unless $access{'view_all_con'} && $access{'kill_con'};
	}
	
&kill_logged('TERM', $in{'pid'});
&webmin_log("kill", undef, $in{'pid'}, \%in);
if ($in{share}) { &redirect("view_users.cgi?share=$in{share}"); }
else { &redirect("view_users.cgi"); }

