#!/usr/local/bin/perl
# Show a form to setup DNSSEC key rotation
use strict;
use warnings;
# Globals
our (%text, %access, %config);

require './bind8-lib.pl';
&ReadParse();
$access{'defaults'} || &error($text{'dnssec_ecannot'});
&ui_print_header(undef, $text{'dnssec_title'}, "",
		 undef, undef, undef, undef, &restart_links());

print $text{'dnssec_desc'},"<p>\n";

print &ui_form_start("save_dnssec.cgi", "post");
print &ui_table_start($text{'dnssec_header'}, undef, 2);

# Rotation enabled?
my $job = &get_dnssec_cron_job();
print &ui_table_row($text{'dnssec_enabled'},
	&ui_yesno_radio("enabled", $job ? 1 : 0));

# Interval in days
print &ui_table_row($text{'dnssec_period'},
	&ui_textbox("period", $config{'dnssec_period'} || 21, 5)." ".
	$text{'dnssec_days'});

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
