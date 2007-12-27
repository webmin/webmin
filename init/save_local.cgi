#!/usr/local/bin/perl
# save_local.cgi
# Save the local startup script

require './init-lib.pl';
$access{'bootup'} == 1 || &error("You are not allowed to edit the bootup script");
&ReadParse();
$in{'local'} =~ s/\r//g;
&lock_file($config{'local_script'});
&open_tempfile(LOCAL, "> $config{'local_script'}");
&print_tempfile(LOCAL, $in{'local'});
&close_tempfile(LOCAL);
&unlock_file($config{'local_script'});
if ($config{'local_down'}) {
	$in{'down'} =~ s/\r//g;
	&lock_file($config{'local_down'});
	&open_tempfile(LOCAL, "> $config{'local_down'}");
	&print_tempfile(LOCAL, $in{'down'});
	&close_tempfile(LOCAL);
	&unlock_file($config{'local_down'});
	}
&webmin_log("local", undef, undef, \%in);
&redirect("");

