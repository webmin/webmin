#!/usr/local/bin/perl
# cancel.cgi
# Cancel one or more downloads

require './updown-lib.pl';
&ReadParse();
&error_setup($text{'cancel_err'});

@ids = split(/\0/, $in{'cancel'});
@ids || &error($text{'cancel_enone'});

# Delete each one, and its At jobs, and kill its PID
if ($can_schedule) {
	&foreign_require("at", "at-lib.pl");
	@ats = &at::list_atjobs();
	}
foreach $i (@ids) {
	$down = &get_download($i);
	&can_as_user($down->{'user'}) ||
		&error(&text('cancel_ecannot', $down->{'user'}));
	next if (!$down);
	&delete_download($down);

	foreach $a (@ats) {
		if ($a->{'realcmd'} =~ /\Q$atjob_cmd\E\s+\Q$i\E/) {
			# Found the job to cancel
			&at::delete_atjob($a->{'id'});
			}
		}

	if ($down->{'pid'}) {
		&kill_logged('TERM', $down->{'pid'});
		}
	}
&webmin_log("cancel", undef, undef, { 'ids' => \@ids });
&redirect("index.cgi?mode=download");

