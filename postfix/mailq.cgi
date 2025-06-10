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
		$s = int($in{'start'});
		$e = $in{'start'} + $config{'perpage'} - 1;
		$e = @qfiles-1 if ($e >= @qfiles);
		print &ui_page_flipper(
			&text('mail_pos', $s+1, $e+1, scalar(@qfiles)),
			undef,
			undef,
			$s ? "mailq.cgi?start=".($s - $config{'perpage'}) : "",
			$e < @qfiles-1 ? "mailq.cgi?start=".($s + $config{'perpage'}) : "",
			);
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

	print &ui_hr();
	print &ui_buttons_start();

	# Show buttons to flush and refresh mail queue
	if (&has_command($config{'postfix_queue_command'})) {
		print &ui_buttons_row("flushq.cgi", $text{'mailq_flush'},
				      $text{'mailq_flushdesc'});
		print &ui_buttons_row("mailq.cgi?$in", $text{'mailq_refresh'},
				      $text{'mailq_refreshdesc'});
		}

	# Show button to clear the mail queue entirely
	print &ui_buttons_row("delete_queues.cgi", $text{'mailq_deleteall'},
			      $text{'mailq_deletealldesc'},
			      [ [ "all", 1 ] ]);

	print &ui_buttons_end();
	}
else {
	print "<b>$text{'mailq_none'}</b> <p>\n";
	}

&ui_print_footer("", $text{'index_return'});


