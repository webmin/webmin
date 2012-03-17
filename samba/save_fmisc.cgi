#!/usr/local/bin/perl
# save_fmisc.cgi
# Save a misc options for a file share

require './samba-lib.pl';
&ReadParse();
&lock_file($config{'smb_conf'});
&get_share($in{old_name});

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pufmisc'}")
            unless &can('rwoO', \%access, $in{old_name});
# save
&error_setup($text{'savefmisc_fail'});
# Random options
&setval("mangled map", $in{mangled_map});
&setval("locking", $in{locking});
if ($in{max_connections_def}) { &setval("max connections", 0); }
else {
	($in{max_connections} =~ /^\d+$/ && $in{max_connections} > 0) ||
		&error(&text('savefmisc_number', $in{max_connections}));
	&setval("max connections", $in{max_connections});
	}
&setval("oplocks", $in{oplocks});
&setval("level2 oplocks", $in{level2_oplocks});
&setval("fake oplocks", $in{fake_oplocks});
&setval("share modes", $in{share_modes});
&setval("strict locking", $in{strict_locking});
&setval("sync always", $in{sync_always});
&setval("volume", $in{volume_def} ? "" : $in{volume});
&setval("preexec", $in{preexec});
&setval("postexec", $in{postexec});
&setval("root preexec", $in{root_preexec});
&setval("root postexec", $in{root_postexec});

&modify_share($in{old_name}, $in{old_name});
&unlock_file($config{'smb_conf'});
&webmin_log("save", "fmisc", $in{old_name}, \%in);
&redirect("edit_fshare.cgi?share=".&urlize($in{old_name}));

