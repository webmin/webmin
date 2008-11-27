#!/usr/local/bin/perl
# Show a list of signing keys, with a form to add

require './bind8-lib.pl';
&ReadParse();
$access{'defaults'} || &error($text{'dnssec_ecannot'});
&ui_print_header(undef, $text{'dnssec_title'}, "",
		 undef, undef, undef, undef, &restart_links());

# Start of tabs
print &ui_tabs_start([ [ "master", $text{'dnssec_master'},
			 "conf_dnssec.cgi?mode=master" ],
		       [ "auto", $text{'dnssec_auto'},
			 "conf_dnssec.cgi?mode=auto" ] ], "mode",
		     $in{'mode'} || "master", 1);

# Master key
print &ui_tabs_start_tab("mode", "master");
print $text{'dnssec_masterdesc'},"<p>\n";
# XXX
print &ui_tabs_end_tab("mode", "master");

# Auto key re-generation
print &ui_tabs_start_tab("mode", "auto");
print $text{'dnssec_autodesc'},"<p>\n";

print &ui_form_start("save_autokey.cgi");
print &ui_table_start($text{'dnssec_header2'}, undef, 2);

# XXX enabled?

# XXX interval in days
# XXX

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

print &ui_tabs_end_tab("mode", "auto");

print &ui_tabs_end(1);

&ui_print_footer("", $text{'index_return'});
