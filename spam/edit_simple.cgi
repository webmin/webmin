#!/usr/local/bin/perl
# Show simple body tests

require './spam-lib.pl';
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("header");
&ui_print_header($header_subtext, $text{'simple_title'}, "");
$conf = &get_config();

print "$text{'simple_desc'}<p>\n";
&start_form("save_simple.cgi", $text{'simple_header'}."\n".
		       "(<a href=edit_header.cgi>$text{'simple_switch'}</a>)");
print "<tr> <td>\n";

# Find the tests we can handle
@simples = &get_simple_tests($conf);

print &ui_columns_start([ $text{'simple_name'},
			  $text{'simple_for'},
			  $text{'simple_regexp'},
			  $text{'simple_score'},
			  $text{'simple_describe'} ], "100");
$i = 0;
foreach $s (@simples, { }, { }, { }) {
	print &ui_columns_row([
		&ui_textbox("name_$i", $s->{'name'}, 20),
		&ui_select("header_$i", $s->{'header'},
			[ [ "subject", "Subject: header" ],
			  [ "from", "From: header" ],
			  [ "to", "To: header" ],
			  [ "cc", "Cc: header" ],
			  [ "received", "Received: header" ],
			  [ "uri", "URL in message" ],
			  [ "body", "Message body" ],
			  [ "full", "Un-decoded body" ] ],
			0, 0, $s->{'header'} ? 1 : 0),
		"/".&ui_textbox("regexp_$i", $s->{'regexp'}, 25)."/".
		    &ui_textbox("flags_$i", $s->{'flags'}, 2),
		&ui_textbox("score_$i", $s->{'score'}, 5),
		&ui_textbox("describe_$i", $s->{'describe'}, 30)
		]);
	$i++;
	}
print &ui_columns_end();

print "</td> </tr>\n";
&end_form(undef, $text{'save'});
&ui_print_footer($redirect_url, $text{'index_return'});

