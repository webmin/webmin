#!/usr/local/bin/perl
# save_defacl.cgi
# Save global ACL options for usermin

require './usermin-lib.pl';
$access{'defacl'} || &error($text{'acl_ecannot'});
&ReadParse();
&error_setup($text{'defacl_err'});

&get_usermin_miniserv_config(\%miniserv);
do "$miniserv{'root'}/acl_security.pl";
&lock_file("$config{'usermin_dir'}/user.acl");
&read_file("$miniserv{'root'}/defaultacl", \%acl);
&read_file("$config{'usermin_dir'}/user.acl", \%acl);
&acl_security_save(\%acl);
&write_file("$config{'usermin_dir'}/user.acl", \%acl);
&unlock_file("$config{'usermin_dir'}/user.acl");
&webmin_log("defacl", undef, undef, \%in);
&redirect("");

