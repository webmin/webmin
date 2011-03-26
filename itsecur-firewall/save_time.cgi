#!/usr/bin/perl
# save_time.cgi
# Create, update or delete a time range

require './itsecur-lib.pl';
&can_edit_error("times");
&lock_itsecur_files();
&ReadParse();
@times = &list_times();
if (!$in{'new'}) {
	$time = $times[$in{'idx'}];
	}

if ($in{'delete'}) {
	# Check if in use
	&error_setup($text{'time_err2'});
	@rules = &list_rules();
	foreach $r (@rules) {
		&error($text{'time_einuse'})
			if ($r->{'time'} eq $time->{'name'});
		}

	# Just delete this time
	splice(@times, $in{'idx'}, 1);
	&automatic_backup();
	}
else {
	# Validate inputs
	&error_setup($text{'time_err'});
	$in{'name'} =~ /^\S+$/ || &error($text{'time_ename'});
	if ($in{'new'} || $in{'name'} ne $time->{'name'}) {
		# Check for clash
		($clash) = grep { lc($_->{'name'}) eq lc($in{'name'}) } @times;
		$clash && &error($text{'time_eclash'});
		}
	if (!$in{'hours_def'}) {
		foreach $t ('from', 'to') {
			$tm = $in{$t};
			$tm =~ /^(\d+):(\d+)$/ || &error($text{'time_e'.$t});
			$1 >= 0 && $1 < 24 || &error($text{'time_ehour'.$t});
			$2 >= 0 && $2 < 60 || &error($text{'time_emin'.$t});
			}
		}
	if (!$in{'days_def'}) {
		@days = split(/\0/, $in{'days'});
		@days || &error($text{'time_edays'});
		}
	$oldname = $time->{'name'};
	$time->{'name'} = $in{'name'};
	$time->{'hours'} = $in{'hours_def'} ? "*" :
				$in{'from'}."-".$in{'to'};
	$time->{'days'} = $in{'days_def'} ? "*" :
				join(",", @days);

	if ($in{'new'}) {
		push(@times, $time);
		}

	&automatic_backup();
	if (!$in{'new'} && $oldname ne $time->{'name'}) {
		# Has been re-named .. update all rules!
		@rules = &list_rules();
		foreach $r (@rules) {
			if ($r->{'time'} eq $oldname) {
				$r->{'time'} = $time->{'name'};
				}
			}
		&save_rules(@rules);
		}
	}

&save_times(@times);
&unlock_itsecur_files();
&remote_webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "update",
	    "time", $time->{'name'}, $time);
&redirect("list_times.cgi");

