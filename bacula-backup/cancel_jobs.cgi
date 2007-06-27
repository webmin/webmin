#!/usr/local/bin/perl
# Cancel running jobs

require './bacula-backup-lib.pl';
&ReadParse();

if (!$in{'refresh'}) {
	# Cancel jobs if not refreshing
	&error_setup($text{'cancel_err'});
	@d = split(/\0/, $in{'d'});
	@d || &error($text{'cancel_enone'});

	$h = &open_console();
	foreach $d (@d) {
		$out = &console_cmd($h, "cancel JobId=$d");
		if ($out =~ /failed|error/i) {
			&error(&text('dvolumes_ebacula', "<tt>$out</tt>"));
			}
		}
	&close_console($h);
	}

if ($in{'client'}) {
	&redirect("clientstatus_form.cgi?client=$in{'client'}");
	}
elsif ($in{'storage'}) {
	&redirect("storagestatus_form.cgi?storage=$in{'storage'}");
	}
else {
	&redirect("dirstatus_form.cgi");
	}

