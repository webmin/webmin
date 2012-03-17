#!/usr/local/bin/perl
# save_fperm.cgi
# Save file permissions options

require './samba-lib.pl';
&ReadParse();
&lock_file($config{'smb_conf'});
&get_share($in{old_name});

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pufperm'}")
            unless &can('rwpP', \%access, $in{old_name});
# save
&error_setup($text{'savefperm_fail'});
# File nameing options
$in{create_mode} =~ /^0?[0-7]{3}$/ ||
	&error(&text('savefperm_mode', $in{create_mode}));
&setval("create mode", $in{create_mode});
&setval("directory mode", $in{directory_mode});
&setval("force create mode", $in{force_create_mode});
&setval("force directory mode", $in{force_directory_mode});
&setval("delete readonly", $in{delete_readonly});
&setval("dont descend", $in{dont_descend});
&setval("force user", $in{force_user});
&setval("force group", $in{force_group});
&setval("wide links", $in{wide_links});

&modify_share($in{old_name}, $in{old_name});
&unlock_file($config{'smb_conf'});
&webmin_log("save", "fperm", $in{old_name}, \%in);
&redirect("edit_fshare.cgi?share=".&urlize($in{old_name}));

