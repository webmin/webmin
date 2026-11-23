#!/usr/local/bin/perl
# Disconnect multiple Samba users

require './samba-lib.pl';
&ReadParse();
@d = split(/\0/, $in{'d'});
@d || &error($text{'viewu_enone'});

# check acls
&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
if ($in{share}) {
	# Per-share rights to view and remove connections
	&error("$text{'eacl_np'} $text{'eacl_pkill'}")
		unless &can_kill_connections($in{'share'});
	}
else {
	&error("$text{'eacl_np'} $text{'eacl_pgkill'}")
		unless &can_kill_connections();
	}

# Kill them, if they all serve the share's current connections
&kill_connection_pids($in{'share'}, @d);
&webmin_log("kills", undef, scalar(@d), \%in);
if ($in{share}) { &redirect("view_users.cgi?share=".&urlize($in{share})); }
else { &redirect("view_users.cgi"); }

