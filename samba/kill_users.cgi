#!/usr/local/bin/perl
# Disconnect multiple Samba users

require './samba-lib.pl';
&ReadParse();
@d = split(/\0/, $in{'d'});
@d || &error($text{'viewu_enone'});

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
	
# Kill them
foreach $pid (@d) {
	&kill_logged('TERM', $pid);
	}
&webmin_log("kills", undef, scalar(@d), \%in);
if ($in{share}) { &redirect("view_users.cgi?share=$in{share}"); }
else { &redirect("view_users.cgi"); }

