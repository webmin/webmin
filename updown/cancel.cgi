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
	# Download IDs are numbers, so they cannot name other files
	$i =~ /^\d+$/ || &error($text{'cancel_eid'});
	$down = &get_download($i);
	next if (!$down);
	&can_as_user($down->{'user'}) ||
		&error(&text('cancel_ecannot', &html_escape($down->{'user'})));
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

