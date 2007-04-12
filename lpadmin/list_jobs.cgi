#!/usr/local/bin/perl
# list_jobs.cgi
# List all print jobs on some printer

require './lpadmin-lib.pl';
&ReadParse();
print "Refresh: $config{'queue_refresh'}\r\n"
	if ($config{'queue_refresh'});
&ui_print_header(undef, $text{'jobs_title'}, "");

@jobs = &get_jobs($in{'name'});
if (@jobs) {
	print &ui_subheading(&text('jobs_header', "<tt>$in{'name'}</tt>"));
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'jobs_id'}</b></td>\n";
	print "<td><b>$text{'jobs_size'}</b></td>\n";
	print "<td><b>$text{'jobs_by'}</b></td>\n";
	if ($jobs[0]->{'when'}) {
		print "<td><b>$text{'jobs_when'}</b></td>\n";
		}
	if ($jobs[0]->{'file'}) {
		print "<td><b>$text{'jobs_file'}</b></td>\n";
		}
	foreach $j (@jobs) {
		local $ju = $j->{'user'};
		$ju =~ s/\!.*$//;
		print "<tr $cb>\n";
		if (&can_edit_jobs($in{'name'}, $ju)) {
			print "<td><a href=\"cancel_job.cgi?name=$in{'name'}&",
			      "id=$j->{'id'}\">",&html_escape($j->{'id'}),
			      "</a></td>\n";
			}
		else {
			print "<td>",&html_escape($j->{'id'}),"</td>\n";
			}
		if ($j->{'printfile'} && &can_edit_jobs($in{'name'}, $ju)) {
			print "<td><a href='view_job.cgi?name=$in{'name'}",
			      "&id=$j->{'id'}'>",&html_escape($j->{'size'}),
			      " $text{'jobs_bytes'}</a></td>\n";
			$printfile++;
			}
		else {
			print "<td>",&html_escape($j->{'size'}),
			      " $text{'jobs_bytes'}</td>\n";
			}
		if ($j->{'user'} =~ /^(\S+)\!(\S+)$/) {
			print "<td>",&html_escape("$2\@$1"),"</td>\n";
			}
		else { print "<td>",&html_escape($j->{'user'}),"</td>\n"; }
		if ($j->{'when'}) { print "<td>$j->{'when'}</td>\n"; }
		if ($j->{'file'}) { print "<td>$j->{'file'}</td>\n"; }
		print "</tr>\n";
		}
	print "</table>\n";
	if ($access{'cancel'}) {
		print "<table width=100%><tr><td>\n";
		print $printfile ? $text{'jobs_cancelview'}
				 : $text{'jobs_cancel'},"<br>\n";
		print "</td> <td align=right>",
		      "<a href='cancel_all.cgi?name=$in{'name'}'>",
		      "$text{'jobs_all'}</a></td> </tr></table>\n";
		}
	}
else {
	print "<b>",&text('jobs_none', "<tt>$in{'name'}</tt>"),"</b><p>\n";
	}

print "<form action=test_form.cgi>\n";
print "<input type=hidden name=name value='$in{'name'}'>\n";
print "<input type=submit value='$text{'jobs_test'}'></form><p>\n";

&ui_print_footer("", $text{'index_return'});


