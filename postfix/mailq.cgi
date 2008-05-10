#!/usr/local/bin/perl
# mailq.cgi
# Display messages currently in the queue.

require './postfix-lib.pl';
require './boxes-lib.pl';
&ReadParse();

$access{'mailq'} || &error($text{'mailq_ecannot'});
&ui_print_header(undef, $text{'mailq_title'}, "");

@qfiles = &list_queue();
if ($config{'mailq_sort'} == 0) {
	@qfiles = sort { $a->{'id'} cmp $b->{'id'} } @qfiles;
	}
elsif ($config{'mailq_sort'} == 1) {
	@qfiles = sort { lc($a->{'from'}) cmp lc($b->{'from'}) } @qfiles;
	}
elsif ($config{'mailq_sort'} == 2) {
	@qfiles = sort { lc($a->{'to'}) cmp lc($b->{'to'}) } @qfiles;
	}
elsif ($config{'mailq_sort'} == 4) {
	@qfiles = sort { lc($a->{'status'}) cmp lc($b->{'status'}) } @qfiles;
	}
elsif ($config{'mailq_sort'} == 5) {
	@qfiles = sort { $b->{'size'} <=> $a->{'size'} } @qfiles;
	}

if (@qfiles) {
	if (@qfiles > $config{'perpage'}) {
		# Need to show arrows
		print "<center>\n";
		$s = int($in{'start'});
		$e = $in{'start'} + $config{'perpage'} - 1;
		$e = @qfiles-1 if ($e >= @qfiles);
		if ($s) {
			printf "<a href='mailq.cgi?start=%d'>%s</a>\n",
			    $s - $config{'perpage'},
			    "<img src=/images/left.gif border=0 align=middle>";
			}
		print "<font size=+1>",&text('mail_pos', $s+1, $e+1,
					     scalar(@qfiles)),"</font>\n";
		if ($e < @qfiles-1) {
			printf "<a href='mailq.cgi?start=%d'>%s</a>\n",
			    $s + $config{'perpage'},
			    "<img src=/images/right.gif border=0 align=middle>";
			}
		print "</center>\n";
		}
	else {
		# Can show them all
		$s = 0;
		$e = @qfiles - 1;
		}

	# Show the mails
	&mailq_table([ @qfiles[$s .. $e] ]);

	# Show queue search form
	print "<form action=mailq_search.cgi>\n";
	print "<b>$text{'mailq_search'}</b>\n";
	print "<select name=field>\n";
	foreach $f ('from', 'to', 'date', 'size', '',
	    	    '!from', '!to', '!date', '!size') {
		printf "<option value='%s'>%s\n", $f, $text{"match_$f"};
		}
	print "</select>\n";
	print "<input name=match size=20>\n";
	print "&nbsp;<input type=submit value='$text{'mail_ok'}'>\n";
	print "</form><p>\n";

	# Show flush button, if the needed command is installed
	if (&has_command($config{'postfix_queue_command'})) {
		print &ui_hr();
		print "<table width=100%><tr><form action=flushq.cgi>\n";
		print "<td><input type=submit ",
		      "value='$text{'mailq_flush'}'></td>\n";
		print "<td>$text{'mailq_flushdesc'}</td>\n";
		print "</form></tr></table>\n";
		}
	}
else {
	print "<b>$text{'mailq_none'}</b> <p>\n";
	}

&ui_print_footer("", $text{'index_return'});


