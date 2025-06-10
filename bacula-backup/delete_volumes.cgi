#!/usr/local/bin/perl
# Delete a bunch of volumes from a pool

require './bacula-backup-lib.pl';
&ReadParse();
&error_setup($text{'dvolumes_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'dvolumes_enone'});

$h = &open_console();
foreach $d (@d) {
	&sysprint($h->{'infh'}, "delete media volume=$d\n");
	$rv = &wait_for($h->{'outfh'}, "Are you sure.*:");
	if ($rv == 0) {
		&sysprint($h->{'infh'}, "yes\n");
		}
	else {
		&error(&text('dvolumes_ebacula', "<tt>$wait_for_input</tt>"));
		}
	}
&close_console($h);

&redirect("poolstatus_form.cgi?pool=$in{'pool'}");

