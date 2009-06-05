#!/usr/local/bin/perl
# list_jobs.cgi
# List all print jobs on some printer

require './lpadmin-lib.pl';
&ReadParse();
print "Refresh: $config{'queue_refresh'}\r\n"
	if ($config{'queue_refresh'});
&ui_print_header(&text('jobs_on', "<tt>$in{'name'}</tt>"), $text{'jobs_title'}, "");

@jobs = &get_jobs($in{'name'});
if (@jobs) {
	if ($access{'cancel'}) {
		# Start of cancel form
		print &ui_form_start("cancel_all.cgi", "post");
		print &ui_hidden("name", $in{'name'});
		@tds = ( "width=5" );
		@links = ( &select_all_link("d"), &select_invert_link("d") );
		print &ui_links_row(\@links);
		}
	print &ui_columns_start([
		$access{'cancel'} ? ( "" ) : ( ),
		$text{'jobs_id'},
		$text{'jobs_size'},
		$text{'jobs_by'},
		$jobs[0]->{'when'} ? ( $text{'jobs_when'} ) : ( ),
		$jobs[0]->{'file'} ? ( $text{'jobs_file'} ) : ( ),
		], 100, 0, \@tds);
	foreach $j (@jobs) {
		local $ju = $j->{'user'};
		$ju =~ s/\!.*$//;
		local @cols;
		push(@cols, &html_escape($j->{'id'}));
		if ($j->{'printfile'} && &can_edit_jobs($in{'name'}, $ju)) {
			push(@cols,
			    "<a href='view_job.cgi?name=$in{'name'}".
			    "&id=$j->{'id'}'>".&nice_size($j->{'size'})."</a>");
			$printfile++;
			}
		else {
			push(@cols, &nice_size($j->{'size'}));
			}
		if ($j->{'user'} =~ /^(\S+)\!(\S+)$/) {
			push(@cols, &html_escape("$2\@$1"));
			}
		else {
			push(@cols, &html_escape($j->{'user'}));
			}
		if ($j->{'when'}) {
			push(@cols, $j->{'when'});
			}
		if ($j->{'file'}) {
			push(@cols, $j->{'file'});
			}
		if (&can_edit_jobs($in{'name'}, $ju) &&
		    $access{'cancel'}) {
			# Can cancel this job
			print &ui_checked_columns_row(\@cols, \@tds,
						      "d", $j->{'id'});
			}
		elsif ($access{'cancel'}) {
			# Can cancel, but not this job
			print &ui_columns_row([ "", @cols ], \@tds);
			}
		else {
			# Cannot cancel at all
			print &ui_columns_row(\@cols, \@tds);
			}
		}
	print &ui_columns_end();
	if ($access{'cancel'}) {
		print &ui_links_row(\@links);
		print &ui_form_end([ [ undef, $text{'jobs_cancelsel'} ] ]);
		}
	}
else {
	print "<b>",&text('jobs_none', "<tt>$in{'name'}</tt>"),"</b><p>\n";
	}

# Test print button
print &ui_form_start("test_form.cgi");
print &ui_hidden("name", $in{'name'});
print &ui_form_end([ [ undef, $text{'jobs_test'} ] ]);

&ui_print_footer("", $text{'index_return'});


