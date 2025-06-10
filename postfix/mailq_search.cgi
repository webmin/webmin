#!/usr/local/bin/perl
# mailq_search.cgi
# Display some messages from the mail queue

require './postfix-lib.pl';
require './boxes-lib.pl';
&ReadParse();
$access{'mailq'} || &error($text{'mailq_ecannot'});
&ui_print_header(undef, $text{'searchq_title'}, "");

# Get all of the queued messages that this user can see
@qfiles = &list_queue();

# Do the search
$neg = ($in{'field'} =~ s/^!//);
@qfiles = grep { my $r = &compare_field($_);
		 $neg ? !$r : $r } @qfiles;

print "<p><b>",&text($in{'field'} =~ /^\!/ ? 'search_results3' :
	  'search_results2', scalar(@qfiles), "<tt>$in{'match'}</tt>"),"</b><p>\n";
if (@qfiles) {
	# Show matching messages
	&mailq_table(\@qfiles);
	}
else {
	print "<b>$text{'searchq_none'}</b> <p>\n";
	}

&ui_print_footer("mailq.cgi", $text{'mailq_return'},
		 "", $text{'index_return'});

sub compare_field
{
if ($in{'field'} eq 'size') {
	return $_[0]->{$in{'field'}} > $in{'match'};
	}
else {
	return $_[0]->{$in{'field'}} =~ /\Q$in{'match'}\E/i;
	}
}

