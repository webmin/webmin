#!/usr/local/bin/perl
# save_popts.cgi
# Save printer options

require './samba-lib.pl';
&ReadParse();
&lock_file($config{'smb_conf'});
&get_share($in{'old_name'});

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pupopt'}")
  		unless &can('rwoO', \%access, $in{old_name});
# save
&error_setup($text{'savepopts_fail'});
# printer options
$in{min_print_space} =~ /^\d+$/ ||
	&error($text{'savepopts_number'});
&setval("min print space", $in{min_print_space});
&setval("postscript", $in{postscript});
&setval("print command", $in{print_command_def} ? "" : $in{print_command});
&setval("lpq command", $in{lpq_command_def} ? "" : $in{lpq_command});
&setval("lprm command", $in{lprm_command_def} ? "" : $in{lprm_command});
&setval("lppause command",
	$in{lppause_command_def} ? "" : $in{lppause_command});
&setval("lpresume command",
	$in{lpresume_command_def} ? "" : $in{lpresume_command});
&setval("printer driver",
	$in{printer_driver_def} ? "" : $in{printer_driver});

# Update config file
&modify_share($in{old_name}, $in{old_name});
&unlock_file($config{'smb_conf'});
&webmin_log("save", "popts", $in{old_name}, \%in);
&redirect("edit_pshare.cgi?share=".&urlize($in{old_name}));

