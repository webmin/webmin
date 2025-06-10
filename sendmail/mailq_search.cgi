#!/usr/local/bin/perl
# mailq_search.cgi
# Display some messages from the mail queue

require './sendmail-lib.pl';
require './boxes-lib.pl';
&ReadParse();
$access{'mailq'} || &error($text{'mailq_ecannot'});
&ui_print_header(undef, $text{'searchq_title'}, "");

# Get all of the queued messages that this user can see
$conf = &get_sendmailcf();
@qfiles = &list_mail_queue($conf);
@qmails = grep { &can_view_qfile($_) }
	       map { &mail_from_queue($_, "auto") } @qfiles;

# Do the search
$fields = [ [ $in{'field'}, $in{'match'} ] ];
@qmails = grep { &mail_matches($fields, 1, $_) } @qmails;
print "<p><b>",&text($in{'field'} =~ /^\!/ ? 'search_results3' :
	  'search_results2', scalar(@qmails), "<tt>$in{'match'}</tt>"),"</b><p>\n";

if (@qmails) {
	%qmails = map { $_->{'file'}, $_ } @qmails;
	&mailq_table([ map { $_->{'file'} } @qmails ], \%qmails);
	}
else {
	print "<b>$text{'searchq_none'}</b> <p>\n";
	}

&ui_print_footer("list_mailq.cgi", $text{'mailq_return'},
	"", $text{'index_return'});

