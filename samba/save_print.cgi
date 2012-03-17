#!/usr/local/bin/perl
# save_print.cgi
# Save inputs from conf_print.cgi

require './samba-lib.pl';
&ReadParse();
&lock_file($config{'smb_conf'});
$global = &get_share("global");

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcprint'}") unless $access{'conf_print'};
 
&error_setup($text{'saveprint_fail'});
&setval("printing", $in{printing}, "");

&setval("load printers", $in{load_printers}, "");

&setval("printcap name", $in{printcap_name_def} ? "" : $in{printcap_name}, "");

if (!$in{lpq_cache_time_def} && $in{lpq_cache_time} !~ /^\d+$/) {
	&error(&text('saveprint_cache', $in{lpq_cache_time}));
	}
&setval("lpq cache time", $in{lpq_cache_time_def} ? 0 : $in{lpq_cache_time}, 0);

if ($global) { &modify_share("global", "global"); }
else { &create_share("global"); }
&unlock_file($config{'smb_conf'});
&webmin_log("print", undef, undef, \%in);
&redirect("");
