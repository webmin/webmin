#!/usr/local/bin/perl
# list_relay.cgi
# List domains to while relaying is allowed

require './sendmail-lib.pl';
$access{'relay'} || &error($text{'relay_ecannot'});
&ui_print_header(undef, $text{'relay_title'}, "");

$conf = &get_sendmailcf();
$ver = &find_type("V", $conf);
if ($ver->{'value'} !~ /^(\d+)/ || $1 < 8) {
	# Only sendmail 8.9 and above supports relay domains (I think)
	print "<b>",$text{'relay_eversion'},"</b> <p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

@dlist = &get_file_or_config($conf, "R");

print &text('relay_desc1', "list_access.cgi"),"<p>\n";
print &text('relay_desc2', "list_mailers.cgi"),"<p>\n";

print &ui_form_start("save_relay.cgi", "form-data");
print &ui_table_start(undef, undef, 2);
print &ui_table_row(undef,
	&ui_textarea("dlist", join("\n", @dlist), 15, 80), 2);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


