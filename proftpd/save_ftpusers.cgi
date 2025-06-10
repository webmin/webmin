#!/usr/local/bin/perl
# save_ftpusers.cgi
# Saves users to be denied access

require './proftpd-lib.pl';
&ReadParse();
@users = split(/\r?\n/, $in{'users'});
&open_lock_tempfile(USERS, ">$config{'ftpusers'}");
foreach $u (@users) {
	&print_tempfile(USERS, $u,"\n");
	}
&close_tempfile(USERS);
&webmin_log("ftpusers", undef, undef);
&redirect("");

