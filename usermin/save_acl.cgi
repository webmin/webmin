#!/usr/local/bin/perl
# save_acl.cgi
# Change visible usermin modules

require './usermin-lib.pl';
$access{'acl'} || &error($text{'acl_ecannot'});
&ReadParse();
&lock_file(&usermin_acl_filename());
@mods = split(/\0/, $in{'mod'});
&save_usermin_acl("user", \@mods);
&unlock_file(&usermin_acl_filename());
&webmin_log("acl", undef, undef, \%in);
&redirect("");

