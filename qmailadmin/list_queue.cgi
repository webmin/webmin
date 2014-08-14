#!/usr/local/bin/perl
# Display the current qmail queue

require './qmail-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'queue_title'}, "");

@queue = &list_queue();
if ($config{'mailq_sort'} == 0) {
	@queue = sort { $a->{'id'} cmp $b->{'id'} } @queue;
	}
elsif ($config{'mailq_sort'} == 1) {
	@queue = sort { lc(&address_parts($a->{'from'})) cmp lc(&address_parts($b->{'from'})) } @queue;
	}
elsif ($config{'mailq_sort'} == 2) {
	@queue = sort { lc(&address_parts($a->{'to'})) cmp lc(&address_parts($b->{'to'})) } @queue;
	}

if (@queue) {
	if (@queue > $config{'perpage'}) {
		# Need to show arrows
		print "<center>\n";
		$s = int($in{'start'});
		$e = $in{'start'} + $config{'perpage'} - 1;
		$e = @queue-1 if ($e >= @queue);
		if ($s) {
			print &ui_link("list_queue.cgi?start=".
				       ($s - $config{'perpage'}),
			    "<img src=/images/left.gif border=0 align=middle>");
			}
		print "<font size=+1>",&text('mail_pos', $s+1, $e+1,
					     scalar(@queue)),"</font>\n";
		if ($e < @queue-1) {
			print &ui_link("list_queue.cgi?start=".
				       ($s + $config{'perpage'}),
			   "<img src=/images/right.gif border=0 align=middle>");
			}
		print "</center>\n";
		}
	else {
		# Can show them all
		$s = 0;
		$e = @queue - 1;
		}
	print "<form action=delete_queues.cgi>\n";
	print &select_all_link("file", 0, $text{'queue_all'}),"&nbsp;\n";
	print &select_invert_link("file", 0, $text{'queue_invert'}),"<br>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><br></td> <td><b>$text{'queue_id'}</b></td> ",
	      "<td><b>$text{'queue_date'}</b></td> ",
	      "<td><b>$text{'queue_from'}</b></td> ",
	      "<td><b>$text{'queue_to'}</b></td> </tr>\n";
	for($i=$s; $i<=$e; $i++) {
		$q = $queue[$i];
		print "<tr $cb>\n";
		print "<td><input type=checkbox name=file value=$q->{'file'}></td>\n";
		print "<td>".&ui_link("view_queue.cgi?file=$q->{'file'}",
				      $q->{'id'})."</td>\n";
		print "<td>$q->{'date'}</td>\n";
		print "<td>",&html_escape($q->{'from'}),"</td>\n";
		print "<td>",&html_escape($q->{'to'}),"</td>\n";
		print "</tr>\n";
		}
	print "</table>\n";
	print &select_all_link("file", 0, $text{'queue_all'}),"&nbsp;\n";
	print &select_invert_link("file", 0, $text{'queue_invert'}),"<p>\n";
	print "<input type=submit value='$text{'queue_delete'}'><p>\n";
	print "</form>\n";

	print &ui_hr();
	print &ui_buttons_start();
	print &ui_buttons_row("list_queue.cgi?$in",
			      $text{'queue_refresh'},
			      $text{'queue_refreshdesc'});
	print &ui_buttons_end();
	}
else {
	print "<b>$text{'queue_none'}</b> <p>\n";
	}

&ui_print_footer("", $text{'index_return'});

