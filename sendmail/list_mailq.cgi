#!/usr/local/bin/perl
# list_mailq.cgi
# Display the current mail queue

require './sendmail-lib.pl';
require './boxes-lib.pl';
&ReadParse();
$access{'mailq'} || &error($text{'mailq_ecannot'});
print "Refresh: $config{'mailq_refresh'}\r\n"
	if ($config{'mailq_refresh'});
&ui_print_header(undef, $text{'mailq_title'}, "");

$conf = &get_sendmailcf();
@qfiles = &list_mail_queue($conf);

if ($access{'qdoms'}) {
	# Filter out blocked mails
	@qfiles = grep { &can_view_qfile($qmails{$_} = &mail_from_queue($_)) }
		       @qfiles;
	}

if ($config{'mailq_sort'} == 0) {
	# Just sort by ID
	@qfiles = sort { $a =~ /\/([^\/]+)$/; local $af = $1;
			 $b =~ /\/([^\/]+)$/; local $bf = $1;
			 $af cmp $bf } @qfiles;
	}
else {
	# We need the actual mails for sorting
	local $q;
	foreach $q (@qfiles) {
		$qmails{$q} ||= &mail_from_queue($q);
		}
	if ($config{'mailq_sort'} == 1) {
		@qfiles = sort { lc(&address_parts($qmails{$a}->{'header'}->{'from'})) cmp
				 lc(&address_parts($qmails{$b}->{'header'}->{'from'})) } @qfiles;
		}
	elsif ($config{'mailq_sort'} == 2) {
		@qfiles = sort { lc(&address_parts($qmails{$a}->{'header'}->{'to'})) cmp
				 lc(&address_parts($qmails{$b}->{'header'}->{'to'})) } @qfiles;
		}
	elsif ($config{'mailq_sort'} == 3) {
		@qfiles = sort { lc($qmails{$a}->{'header'}->{'subject'}) cmp
				 lc($qmails{$b}->{'header'}->{'subject'}) } @qfiles;
		}
	elsif ($config{'mailq_sort'} == 4) {
		@qfiles = sort { lc($qmails{$a}->{'status'}) cmp
				 lc($qmails{$b}->{'status'}) } @qfiles;
		}
	elsif ($config{'mailq_sort'} == 5) {
		@qfiles = sort { $qmails{$b}->{'size'} <=>
				 $qmails{$a}->{'size'} } @qfiles;
		}
	}


if (@qfiles) {
	if (@qfiles > $config{'perpage'}) {
		# Need to show arrows
		print "<center>\n";
		$s = int($in{'start'});
		$e = $in{'start'} + $config{'perpage'} - 1;
		$e = @qfiles-1 if ($e >= @qfiles);
		if ($s) {
			print &ui_link("list_mailq.cgi?start=".
				        ($s - $config{'perpage'}),
			    "<img src=/images/left.gif border=0 align=middle>");
			}
		print "<font size=+1>",&text('mail_pos', $s+1, $e+1,
					     scalar(@qfiles)),"</font>\n";
		if ($e < @qfiles-1) {
			print &ui_link("list_mailq.cgi?start=".
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

	# Show the queued mails
	$quarcount = &mailq_table([ @qfiles[$s .. $e] ], \%qmails);

	# Show queue search form
	print "<form action=mailq_search.cgi>\n";
	print "<b>$text{'mailq_search'}</b>\n";
	print "<select name=field>\n";
	foreach $f ('from', 'subject', 'to', 'cc', 'date', 'status', 'body', 'headers', 'size', '',
	    '!from', '!subject', '!to', '!cc', '!date', '!status', '!body', '!headers', '!size') {
		printf "<option value='%s'>%s</option>\n", $f, $text{"match_$f"};
		}
	print "</select>\n";
	print "<input name=match size=20>\n";
	print "&nbsp;<input type=submit value='$text{'mail_ok'}'>\n";
	print "</form>\n";

	# Show flush button(s)
	if ($access{'flushq'}) {
		print &ui_hr();
		print &ui_buttons_start();
		print &ui_buttons_row("flushq.cgi",
				      $text{'mailq_flush'},
				      $text{'mailq_flushdesc'});
		if ($quarcount) {
			print &ui_buttons_row("flushq.cgi",
					      $text{'mailq_flushquar'},
					      $text{'mailq_flushquardesc'},
					      &ui_hidden("quar", 1));
			}
		print &ui_buttons_row("list_mailq.cgi?$in",
				      $text{'mailq_refresh'},
				      $text{'mailq_refreshdesc'});
		print &ui_buttons_end();
		}
	}
else {
	print "<b>$text{'mailq_none'}</b> <p>\n";
	}

&ui_print_footer("", $text{'index_return'});

