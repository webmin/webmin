#!/usr/local/bin/perl
# save_access.cgi
# Save readers and writers lists

require './pserver-lib.pl';
$access{'access'} || &error($text{'access_ecannot'});
&ReadParse();
&error_setup($text{'access_err'});

&lock_file($readers_file);
@passwd = &list_passwords();
%gotuser = map { $_->{'user'}, 1 } @passwd;
if ($in{'readers_def'}) {
	unlink($readers_file);
	}
else {
	@readers = split(/\s+/, $in{'readers'});
	foreach $r (@readers) {
		defined(getpwnam($r)) || $gotuser{$r} ||
			&error(&text('access_euser', $r));
		}
	&open_tempfile(READERS, ">$readers_file");
	foreach $r (@readers) {
		&print_tempfile(READERS, $r,"\n");
		}
	&close_tempfile(READERS);
	}
&unlock_file($readers_file);

&lock_file($writers_file);
if ($in{'writers_def'}) {
	unlink($writers_file);
	}
else {
	@writers = split(/\s+/, $in{'writers'});
	foreach $r (@writers) {
		defined(getpwnam($r)) || $gotuser{$r} ||
			&error(&text('access_euser', $r));
		}
	&open_tempfile(WRITERS, ">$writers_file");
	foreach $r (@writers) {
		&print_tempfile(WRITERS, $r,"\n");
		}
	&close_tempfile(WRITERS);
	}
&unlock_file($writers_file);
&webmin_log("access");

&redirect("");

