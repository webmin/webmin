#!/usr/local/bin/perl
# Delete a bunch of shares at once

require './samba-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});


@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

&lock_file($config{'smb_conf'});
foreach $d (@d) {
	&error("$text{'eacl_np'} $text{'eacl_pds'}") 
		unless &can('rw', \%access, $d);
	foreach $s (&list_shares()) {
		&get_share($s);
		if (&getval("copy") eq $d) {
			&error(&text('error_delcopy', $s));
			}
		}
	&delete_share($d);
	&drop_samba_acl(\%access, $d);
	}
&unlock_file($config{'smb_conf'});
&webmin_log("delete", "shares", scalar(@d));
&redirect("");

