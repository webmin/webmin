#!/usr/local/bin/perl
# delete_share.cgi
# Delete an existing share

require './samba-lib.pl';
&ReadParse();

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pds'}") 
	unless &can('rw', \%access, $in{share});
# delete
&error_setup($text{'error_delshare'});
&lock_file($config{'smb_conf'});
foreach $s (&list_shares()) {
	&get_share($s);
	if (&getval("copy") eq $in{share}) {
		&error(&text('error_delcopy', $s));
		}
	}
&delete_share($in{share});
&drop_samba_acl(\%access, $in{share});
&unlock_file($config{'smb_conf'});
&webmin_log("delete", $in{'type'}, $in{share});
&redirect("");

