#!/usr/local/bin/perl
# save_copy.cgi
# Create a new, empty share that is a copy of an existing one

require './samba-lib.pl';
&ReadParse();

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcopy'}") unless $access{'copy'};
 
&error_setup($text{'savecopy_fail'});
&lock_file($config{'smb_conf'});
$in{'name'} || &error($text{'savecopy_ename'});
if ($in{"name"} eq "global") {
	&error($text{'savecopy_global'});
	}
if (&indexof($in{"name"}, &list_shares()) >= 0) {
	&error(&text('savecopy_exist', $in{name}));
	}
&setval("copy", $in{copy});
&create_share($in{name});
&unlock_file($config{'smb_conf'});
&webmin_log("copy", undef, $in{'name'}, \%in);
&redirect("");

