#!/usr/local/bin/perl
# kill_user.cgi
# Kill a samba process connecting to some client

require './samba-lib.pl';
&ReadParse();

# check acls
&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
if ($in{'share'}) {
	# Per-share rights to view and remove connections
	&error("$text{'eacl_np'} $text{'eacl_pkill'}")
		unless &can_kill_connections($in{'share'});
	}
else {
	&error("$text{'eacl_np'} $text{'eacl_pgkill'}")
		unless &can_kill_connections();
	}

# Only processes serving the share's current connections can be killed
&kill_connection_pids($in{'share'}, $in{'pid'});
&webmin_log("kill", undef, $in{'pid'}, \%in);
if ($in{share}) { &redirect("view_users.cgi?share=".&urlize($in{share})); }
else { &redirect("view_users.cgi"); }

