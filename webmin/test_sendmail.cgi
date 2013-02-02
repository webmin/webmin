#!/usr/local/bin/perl
# Send a test email

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'testmail_err'});
&foreign_require("mailboxes");

# Validate inputs
$in{'to'} =~ /^\S+\@\S+$/ || &error($text{'testmail_eto'});

# Send it
&ui_print_unbuffered_header(undef, $text{'testmail_title'}, "");

$from = &mailboxes::get_from_address();
print &text('testmail_sending', $from, &html_escape($in{'to'})),"<br>\n";
eval {
	local $main::error_must_die = 1;
	$rv = &mailboxes::send_text_mail($from, $in{'to'}, undef,
					 $in{'subject'}, $in{'body'});
	};
if ($@) {
	my $err = $@;
	$err =~ s/\s+at\s+\S+\s+line\s+\d+//;
	print &text('testmail_failed', $err),"<p>\n";
	}
else {
	print $text{'testmail_done'},"<p>\n";
	}

&ui_print_footer("", $text{'index_return'});
