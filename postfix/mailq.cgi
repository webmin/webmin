#!/usr/local/bin/perl
# mailq.cgi
# Display messages currently in the queue.

require './postfix-lib.pl';
require './boxes-lib.pl';
&ReadParse();

$access{'mailq'} || &error($text{'mailq_ecannot'});
&ui_print_header(undef, $text{'mailq_title'}, "");

# Get queued messages and sort
@qfiles = &list_queue(1);
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
elsif ($config{'mailq_sort'} == 6) {
	@qfiles = sort { $b->{'time'} <=> $a->{'time'} } @qfiles;
	}

if (@qfiles) {
	if (@qfiles > $config{'perpage'}) {
		# Need to show arrows
		print "<center>\n";
		$s = int($in{'start'});
		$e = $in{'start'} + $config{'perpage'} - 1;
		$e = @qfiles-1 if ($e >= @qfiles);
		if ($s) {
			print &ui_link("mailq.cgi?start=".
					($s - $config{'perpage'}),
			    "<img src=/images/left.gif border=0 align=middle>");
			}
		print "<font size=+1>",&text('mail_pos', $s+1, $e+1,
					     scalar(@qfiles)),"</font>\n";
		if ($e < @qfiles-1) {
			print &ui_link("mailq.cgi?start=".
				       ($s + $config{'perpage'}),
			    "<img src=/images/right.gif border=0 align=middle>");
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
	print &ui_form_start("mailq_search.cgi");
	print "<b>$text{'mailq_search'}</b>\n";
	print &ui_select("field", "from",
		[ map { [ $_, $text{'match_'.$_} ] }
		    ('from', 'to', 'date', 'size', '',
		     '!from', '!to', '!date', '!size') ]);
	print &ui_textbox("match", undef, 40);
	print &ui_submit($text{'mail_ok'});
	print &ui_form_end();

	# Show flush button, if the needed command is installed
	if (&has_command($config{'postfix_queue_command'})) {
		print &ui_hr();
		print &ui_buttons_start();
		print &ui_buttons_row("flushq.cgi", $text{'mailq_flush'},
				      $text{'mailq_flushdesc'});
		print &ui_buttons_row("mailq.cgi?$in", $text{'mailq_refresh'},
				      $text{'mailq_refreshdesc'});
		print &ui_buttons_end();
		}
	}
else {
	print "<b>$text{'mailq_none'}</b> <p>\n";
	}

&ui_print_footer("", $text{'index_return'});


