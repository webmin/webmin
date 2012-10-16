#!/usr/local/bin/perl
# Show global timeout options

use strict;
use warnings;
require './iscsi-target-lib.pl';
our (%text);
my $conf = &get_iscsi_config();

&ui_print_header(undef, $text{'timeout_title'}, "");

print &ui_form_start("save_timeout.cgi", "post");
print &ui_table_start($text{'timeout_header'}, undef, 2);

# Time between pings
my $n = &find_value($conf, "NOPInterval");
print &ui_table_row($text{'timeout_nopi'},
	&ui_opt_textbox("nopi", $n, 5, $text{'timeout_nopinone'})." ".
	$text{'timeout_secs'});

# Time to respond to ping before disconnecting
$n = &find_value($conf, "NOPTimeout");
print &ui_table_row($text{'timeout_nopt'},
	&ui_opt_textbox("nopt", $n, 5, $text{'timeout_noptnone'})." ".
	$text{'timeout_secs'});

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
