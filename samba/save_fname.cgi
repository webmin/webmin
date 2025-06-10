#!/usr/local/bin/perl
# save_fname.cgi
# Save file naming options

require './samba-lib.pl';
&ReadParse();
&lock_file($config{'smb_conf'});
&get_share($in{old_name});

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pufname'}")
            unless &can('rwnN', \%access, $in{old_name});
# save
&error_setup($text{'error_savename'});
# File nameing options
&setval("mangle case", $in{mangle_case});
&setval("case sensitive", $in{case_sensitive});
&setval("default case", $in{default_case}, "lower");
&setval("preserve case", $in{preserve_case});
&setval("short preserve case", $in{short_preserve_case});
&setval("hide dot files", $in{hide_dot_files});
&setval("map archive", $in{map_archive});
&setval("map hidden", $in{map_hidden});
&setval("map system", $in{map_system});

&modify_share($in{old_name}, $in{old_name});
&unlock_file($config{'smb_conf'});
&webmin_log("save", "fname", $in{old_name}, \%in);
&redirect("edit_fshare.cgi?share=".&urlize($in{old_name}));

