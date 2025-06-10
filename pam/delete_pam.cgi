#!/usr/local/bin/perl
# delete_pam.cgi
# Delete a PAM service

require './pam-lib.pl';
&ReadParse();
@pam = &get_pam_config();
$f = $pam[$in{'idx'}]->{'file'};
&lock_file($f);
unlink($f);
&unlock_file($f);
&webmin_log("delete", "pam", $pam[$in{'idx'}]->{'name'}, $pam);
&redirect("");

